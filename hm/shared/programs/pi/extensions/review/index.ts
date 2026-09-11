import { readFileSync } from "node:fs";

import { type Message } from "@earendil-works/pi-ai";
import {
  buildSessionContext,
  defineTool,
  getMarkdownTheme,
  type ExtensionAPI,
  type ExtensionCommandContext,
  type ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { Box, Markdown, Text } from "@earendil-works/pi-tui";

import {
  appendInterceptorRules,
  GIT_INSPECTION_BASH_POLICY,
} from "../interceptor/index.ts";

const REVIEW_RESULT_TYPE = "review-result";
const REVIEW_STATE_TYPE = "review-session";
const REVIEW_ANCHOR_TYPE = "review-anchor";
const REVIEW_WIDGET_KEY = "review";
const REVIEW_TOOLS = ["read", "bash"];
const REVIEW_BRIEF_CHARACTERS_MAX = 30_000;
const REVIEW_BRIEF_HEAD_CHARACTERS = 10_000;
const REVIEW_BRIEF_OMISSION =
  "\n\n[Earlier conversation omitted from the review brief.]\n\n";
const REVIEW_CONTEXT_PLACEHOLDER = "{{CURRENT_SESSION_CONTEXT}}";
const REVIEW_INSTRUCTIONS_PLACEHOLDER = "{{REVIEW_INSTRUCTIONS}}";
const REVIEW_PROMPT_TEMPLATE = readFileSync(
  new URL("./review-prompt.txt", import.meta.url),
  "utf8",
).trim();
const REVIEW_PROMPT_PLACEHOLDER_PATTERN =
  /\{\{(?:CURRENT_SESSION_CONTEXT|REVIEW_INSTRUCTIONS)\}\}/gu;

for (const placeholder of [
  REVIEW_CONTEXT_PLACEHOLDER,
  REVIEW_INSTRUCTIONS_PLACEHOLDER,
]) {
  if (REVIEW_PROMPT_TEMPLATE.split(placeholder).length !== 2) {
    throw new Error(
      `Review prompt must contain exactly one ${placeholder} placeholder.`,
    );
  }
}

type ReviewSessionState = {
  active: boolean;
  originId?: string;
  previousTools?: string[];
};

type ReviewPreflight = { ok: true } | { ok: false; error: string };

function extractMessageText(message: Message): string {
  if (!("content" in message) || !Array.isArray(message.content)) {
    return "";
  }
  return message.content
    .filter((part): part is { type: "text"; text: string } => {
      return (
        !!part &&
        typeof part === "object" &&
        part.type === "text" &&
        typeof part.text === "string"
      );
    })
    .map((part) => part.text)
    .join("\n")
    .trim();
}

function safeSliceStart(text: string, length: number): string {
  let end = Math.min(length, text.length);
  if (end > 0 && end < text.length && /[\uD800-\uDBFF]/u.test(text[end - 1])) {
    end--;
  }
  return text.slice(0, end);
}

function safeSliceEnd(text: string, length: number): string {
  let start = Math.max(0, text.length - length);
  if (
    start > 0 &&
    start < text.length &&
    /[\uDC00-\uDFFF]/u.test(text[start])
  ) {
    start++;
  }
  return text.slice(start);
}

export function boundReviewBrief(brief: string): string {
  if (brief.length <= REVIEW_BRIEF_CHARACTERS_MAX) {
    return brief;
  }
  const tailLength =
    REVIEW_BRIEF_CHARACTERS_MAX -
    REVIEW_BRIEF_HEAD_CHARACTERS -
    REVIEW_BRIEF_OMISSION.length;
  return [
    safeSliceStart(brief, REVIEW_BRIEF_HEAD_CHARACTERS),
    REVIEW_BRIEF_OMISSION,
    safeSliceEnd(brief, tailLength),
  ].join("");
}

export function buildReviewConversationBrief(messages: Message[]): string {
  const sections: string[] = [];
  for (const message of messages) {
    if (message.role !== "user" && message.role !== "assistant") {
      continue;
    }
    const text = extractMessageText(message);
    if (text) {
      sections.push(
        `${message.role === "user" ? "User" : "Assistant"}: ${text}`,
      );
    }
  }
  return boundReviewBrief(sections.join("\n\n"));
}

function getReviewConversationBrief(ctx: ExtensionContext): string {
  try {
    const context = buildSessionContext(
      ctx.sessionManager.getEntries(),
      ctx.sessionManager.getLeafId(),
    );
    return buildReviewConversationBrief(
      context.messages.filter((message) => "role" in message) as Message[],
    );
  } catch {
    return "";
  }
}

export function buildReviewPrompt(
  instructions: string,
  conversationBrief: string,
): string {
  const requestedInstructions =
    instructions.trim() ||
    "Review all staged, unstaged, and untracked changes.";
  const contextSection = conversationBrief
    ? `<current_session_context>\n${conversationBrief}\n</current_session_context>\n\n`
    : "";
  const replacements: Record<string, string> = {
    [REVIEW_CONTEXT_PLACEHOLDER]: contextSection,
    [REVIEW_INSTRUCTIONS_PLACEHOLDER]: requestedInstructions,
  };
  return REVIEW_PROMPT_TEMPLATE.replace(
    REVIEW_PROMPT_PLACEHOLDER_PATTERN,
    (placeholder) => replacements[placeholder] ?? placeholder,
  );
}

function getReviewState(ctx: ExtensionContext): ReviewSessionState | undefined {
  let state: ReviewSessionState | undefined;
  for (const entry of ctx.sessionManager.getBranch()) {
    if (entry.type === "custom" && entry.customType === REVIEW_STATE_TYPE) {
      state = entry.data as ReviewSessionState | undefined;
    }
  }
  return state;
}

export function findLatestReviewReport(messages: Message[]): string {
  for (let index = messages.length - 1; index >= 0; index--) {
    const message = messages[index];
    if (message.role !== "assistant") continue;
    if (message.stopReason !== "stop") return "";
    return extractMessageText(message);
  }
  return "";
}

function getLatestReviewReport(ctx: ExtensionContext): string {
  const messages = ctx.sessionManager
    .getBranch()
    .filter((entry) => entry.type === "message")
    .map((entry) => entry.message as Message);
  return findLatestReviewReport(messages);
}

function setReviewWidget(ctx: ExtensionContext, active: boolean): void {
  if (!active) {
    ctx.ui.setWidget(REVIEW_WIDGET_KEY, undefined);
    return;
  }
  ctx.ui.setWidget(REVIEW_WIDGET_KEY, (_tui, theme) => {
    return new Text(
      theme.fg("dim", "Review session · /end-review to return"),
      0,
      0,
    );
  });
}

async function prepareReview(
  pi: ExtensionAPI,
  ctx: ExtensionCommandContext,
  instructions: string,
): Promise<ReviewPreflight> {
  if (!ctx.model) {
    return { ok: false, error: "No active model selected." };
  }
  const workTree = await pi.exec(
    "git",
    ["rev-parse", "--is-inside-work-tree"],
    {
      cwd: ctx.cwd,
      timeout: 5_000,
    },
  );
  if (workTree.code !== 0 || workTree.stdout.trim() !== "true") {
    return { ok: false, error: "Review requires a Git working tree." };
  }
  if (!instructions.trim()) {
    const status = await pi.exec(
      "git",
      ["status", "--porcelain=v1", "--untracked-files=all"],
      {
        cwd: ctx.cwd,
        timeout: 5_000,
      },
    );
    if (status.code !== 0) {
      return {
        ok: false,
        error: status.stderr.trim() || "Unable to inspect uncommitted changes.",
      };
    }
    if (!status.stdout.trim()) {
      return { ok: false, error: "No uncommitted changes to review." };
    }
  }
  return { ok: true };
}

export function filterReviewAutocompleteItems<T extends { value: string }>(
  items: T[],
  reviewActive: boolean,
): T[] {
  return reviewActive
    ? items
    : items.filter((item) => item.value !== "end-review");
}

export default function reviewExtension(pi: ExtensionAPI): void {
  let reviewOriginId: string | undefined;
  let previousTools: string[] | undefined;
  let navigationInProgress = false;
  let autocompleteInstalled = false;
  let releaseInspectionRules: (() => void) | undefined;
  const markdownTheme = getMarkdownTheme();

  const enableInspectionRules = (ctx: ExtensionContext) => {
    releaseInspectionRules?.();
    releaseInspectionRules = appendInterceptorRules(
      GIT_INSPECTION_BASH_POLICY,
      ctx.cwd,
    );
  };

  const leaveReviewMode = (ctx: ExtensionContext) => {
    releaseInspectionRules?.();
    releaseInspectionRules = undefined;
    if (previousTools) {
      pi.setActiveTools(previousTools);
    }
    reviewOriginId = undefined;
    previousTools = undefined;
    setReviewWidget(ctx, false);
  };

  const applyReviewState = (ctx: ExtensionContext) => {
    if (navigationInProgress) return;
    const state = getReviewState(ctx);
    if (state?.active && state.originId) {
      reviewOriginId = state.originId;
      previousTools = state.previousTools;
      enableInspectionRules(ctx);
      pi.setActiveTools(REVIEW_TOOLS);
      setReviewWidget(ctx, true);
      return;
    }
    leaveReviewMode(ctx);
  };

  const installReviewAutocomplete = (ctx: ExtensionContext) => {
    if (autocompleteInstalled) return;
    autocompleteInstalled = true;
    ctx.ui.addAutocompleteProvider((current) => ({
      triggerCharacters: current.triggerCharacters,
      async getSuggestions(lines, cursorLine, cursorCol, options) {
        const suggestions = await current.getSuggestions(
          lines,
          cursorLine,
          cursorCol,
          options,
        );
        if (!suggestions) return null;
        return {
          ...suggestions,
          items: filterReviewAutocompleteItems(
            suggestions.items,
            reviewOriginId !== undefined,
          ),
        };
      },
      applyCompletion(lines, cursorLine, cursorCol, item, prefix) {
        return current.applyCompletion(
          lines,
          cursorLine,
          cursorCol,
          item,
          prefix,
        );
      },
      shouldTriggerFileCompletion(lines, cursorLine, cursorCol) {
        return (
          current.shouldTriggerFileCompletion?.(lines, cursorLine, cursorCol) ??
          true
        );
      },
    }));
  };

  pi.registerMessageRenderer(
    REVIEW_RESULT_TYPE,
    (message, { outputPad }, theme) => {
      const content =
        typeof message.content === "string"
          ? message.content
          : message.content
              .filter(
                (part): part is { type: "text"; text: string } =>
                  part.type === "text",
              )
              .map((part) => part.text)
              .join("\n");
      const box = new Box(outputPad, 1, (text) =>
        theme.bg("customMessageBg", text),
      );
      box.addChild(new Markdown(content, 0, 0, markdownTheme));
      return box;
    },
  );

  pi.registerCommand("review", {
    description:
      "Start an isolated review branch (usage: /review [instructions])",
    handler: async (args, ctx) => {
      if (reviewOriginId || getReviewState(ctx)?.active) {
        ctx.ui.notify("Already in a review. Use /end-review first.", "warning");
        return;
      }
      const instructions = args.trim();
      const preflight = await prepareReview(pi, ctx, instructions);
      if (!preflight.ok) {
        ctx.ui.notify(
          preflight.error,
          preflight.error === "No uncommitted changes to review."
            ? "info"
            : "error",
        );
        return;
      }

      const conversationBrief = getReviewConversationBrief(ctx);
      pi.appendEntry(REVIEW_ANCHOR_TYPE, {
        createdAt: new Date().toISOString(),
      });
      const originId = ctx.sessionManager.getLeafId() ?? undefined;
      if (!originId) {
        ctx.ui.notify("Failed to determine review origin.", "error");
        return;
      }

      const savedTools = pi.getActiveTools();
      const firstUserMessage = ctx.sessionManager
        .getEntries()
        .find(
          (entry) => entry.type === "message" && entry.message.role === "user",
        );
      navigationInProgress = true;
      try {
        if (firstUserMessage) {
          const result = await ctx.navigateTree(firstUserMessage.id, {
            summarize: false,
            label: "code-review",
          });
          if (result.cancelled) return;
          ctx.ui.setEditorText("");
        }
      } catch (error) {
        ctx.ui.notify(
          `Failed to start review: ${error instanceof Error ? error.message : String(error)}`,
          "error",
        );
        return;
      } finally {
        navigationInProgress = false;
      }

      reviewOriginId = originId;
      previousTools = savedTools;
      enableInspectionRules(ctx);
      pi.setActiveTools(REVIEW_TOOLS);
      setReviewWidget(ctx, true);
      pi.appendEntry(REVIEW_STATE_TYPE, {
        active: true,
        originId,
        previousTools: savedTools,
      } satisfies ReviewSessionState);
      pi.sendUserMessage(buildReviewPrompt(instructions, conversationBrief));
    },
  });

  pi.registerCommand("end-review", {
    description: "Return from the review branch with its final report",
    handler: async (_args, ctx) => {
      const state = getReviewState(ctx);
      const originId = reviewOriginId ?? state?.originId;
      if (!originId) {
        ctx.ui.notify("No review is active.", "info");
        return;
      }
      if (!ctx.isIdle()) {
        ctx.ui.notify(
          "Interrupt the active review before using /end-review.",
          "warning",
        );
        return;
      }

      const report = getLatestReviewReport(ctx);
      const toolsToRestore = previousTools ?? state?.previousTools ?? [];
      navigationInProgress = true;
      try {
        const result = await ctx.navigateTree(originId, { summarize: false });
        if (result.cancelled) {
          ctx.ui.notify(
            "Navigation cancelled. Use /end-review to try again.",
            "info",
          );
          return;
        }
      } catch (error) {
        ctx.ui.notify(
          `Failed to end review: ${error instanceof Error ? error.message : String(error)}`,
          "error",
        );
        return;
      } finally {
        navigationInProgress = false;
      }

      previousTools = toolsToRestore;
      leaveReviewMode(ctx);
      pi.appendEntry(REVIEW_STATE_TYPE, {
        active: false,
      } satisfies ReviewSessionState);
      pi.sendMessage(
        {
          customType: REVIEW_RESULT_TYPE,
          content: report || "Review ended without a complete report.",
          display: true,
        },
        { triggerTurn: false },
      );
    },
  });

  pi.on("session_start", (_event, ctx) => {
    applyReviewState(ctx);
    installReviewAutocomplete(ctx);
  });
  pi.on("session_tree", (_event, ctx) => applyReviewState(ctx));
  pi.on("session_shutdown", async (_event, ctx) => {
    leaveReviewMode(ctx);
  });
}
