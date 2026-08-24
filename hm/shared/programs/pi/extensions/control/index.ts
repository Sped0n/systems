import type {
  ExtensionAPI,
  ExtensionContext,
  MessageRenderer,
} from "@earendil-works/pi-coding-agent";
import {
  FooterComponent,
  getAgentDir,
  getMarkdownTheme,
} from "@earendil-works/pi-coding-agent";
import type { TextContent } from "@earendil-works/pi-ai";
import {
  Box,
  Markdown,
  Spacer,
  Text,
  truncateToWidth,
  visibleWidth,
} from "@earendil-works/pi-tui";
import * as path from "node:path";

import {
  ensureSessionControlDirectory,
  getSessionControlDirectory,
  getSessionEndpointPaths,
  publishSessionEndpoint,
  removeSessionEndpoint,
} from "./discovery.ts";
import {
  shortSessionId,
  type AssistantResult,
  type SendOptions,
  type SessionEndpoint,
} from "./protocol.ts";
import {
  SessionControlServer,
  type ControlledSession,
} from "./server.ts";

const AUTISTIC_MODE_FLAG = "autistic-mode";
const SESSION_MESSAGE_TYPE = "session-message";

interface RuntimeState {
  server?: SessionControlServer;
  context?: ExtensionContext;
  endpoint?: SessionEndpoint;
}

/** Paste into an editor draft and force Pi 0.84 to render the external update. */
export function pasteEditorDraft(
  ui: Pick<ExtensionContext["ui"], "pasteToEditor" | "setStatus">,
  text: string,
): void {
  ui.pasteToEditor(text);
  // pasteToEditor mutates the editor but does not request a render itself.
  ui.setStatus("pi-control-paste-refresh", undefined);
}

function installControlFooter(
  ctx: ExtensionContext,
  state: RuntimeState,
  marker: string,
): void {
  if (ctx.mode !== "tui") return;
  ctx.ui.setFooter((tui, theme, footerData) => {
    const session = {
      get state() {
        const current = state.context ?? ctx;
        return { model: current.model, thinkingLevel: current.thinkingLevel };
      },
      sessionManager: ctx.sessionManager,
      getContextUsage: () => (state.context ?? ctx).getContextUsage(),
      modelRuntime: { isUsingSubscription: () => false },
    } as unknown as ConstructorParameters<typeof FooterComponent>[0];
    const footer = new FooterComponent(session, footerData);
    const unsubscribe = footerData.onBranchChange(() => tui.requestRender());
    return {
      render(width: number): string[] {
        const lines = footer.render(width);
        const right = theme.fg("dim", marker);
        const rightWidth = visibleWidth(right);
        const left = truncateToWidth(
          lines[0] ?? "",
          Math.max(0, width - rightWidth - 1),
          "",
        );
        const padding = " ".repeat(
          Math.max(1, width - visibleWidth(left) - rightWidth),
        );
        return [`${left}${padding}${right}`, ...lines.slice(1)];
      },
      invalidate: () => footer.invalidate(),
      dispose() {
        unsubscribe();
        footer.dispose();
      },
    };
  });
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function textContent(
  content: string | Array<TextContent | { type: string }>,
): string {
  if (typeof content === "string") return content;
  return content
    .filter((part): part is TextContent => part.type === "text")
    .map((part) => part.text)
    .join("\n");
}

function lastAssistantMessage(ctx: ExtensionContext): AssistantResult | null {
  const branch = ctx.sessionManager.getBranch();
  for (let index = branch.length - 1; index >= 0; index -= 1) {
    const entry = branch[index];
    if (entry.type !== "message" || entry.message.role !== "assistant")
      continue;
    if (
      entry.message.stopReason !== "stop" &&
      entry.message.stopReason !== "length"
    )
      continue;
    const text = textContent(entry.message.content).trim();
    if (!text) continue;
    return { text, timestamp: entry.message.timestamp, messageId: entry.id };
  }
  return null;
}

function senderSuffix(sender: SendOptions["sender"]): string {
  if (!sender) return "";
  return `\n\n<sender_info>${JSON.stringify(sender)}</sender_info>`;
}

function createControlledSession(
  pi: ExtensionAPI,
  state: RuntimeState,
  ctx: ExtensionContext,
): ControlledSession {
  return {
    describe: () => {
      if (!state.endpoint) throw new Error("Session endpoint is unavailable");
      return state.endpoint;
    },
    async send(options) {
      pi.sendMessage(
        {
          customType: SESSION_MESSAGE_TYPE,
          content: options.message + senderSuffix(options.sender),
          display: true,
          details: { sender: options.sender },
        },
        { triggerTurn: true, deliverAs: "steer" },
      );
      return { accepted: true };
    },
    async paste(text) {
      pasteEditorDraft(ctx.ui, text);
      return { pasted: true };
    },
    getLastMessage: () => lastAssistantMessage(ctx),
  };
}

function stripSenderInfo(content: string): string {
  return content
    .replace(/\n*<sender_info>[\s\S]*?<\/sender_info>\s*$/u, "")
    .trim();
}

const renderSessionMessage: MessageRenderer = (
  message,
  { expanded, outputPad },
  theme,
) => {
  let content = stripSenderInfo(textContent(message.content));
  if (!content) content = "(no content)";
  if (!expanded) {
    const lines = content.split("\n");
    if (lines.length > 5) content = `${lines.slice(0, 5).join("\n")}\n...`;
  }
  const sender =
    isObject(message.details) && isObject(message.details.sender)
      ? message.details.sender
      : undefined;
  const senderName =
    typeof sender?.sessionName === "string"
      ? sender.sessionName
      : typeof sender?.sessionId === "string"
        ? sender.sessionId
        : undefined;
  const box = new Box(outputPad, 1, (text) =>
    theme.bg("customMessageBg", text),
  );
  let label = theme.fg("customMessageLabel", theme.bold("[session-message]"));
  if (senderName) label += ` ${theme.fg("dim", `from ${senderName}`)}`;
  box.addChild(new Text(label, 0, 0));
  box.addChild(new Spacer(1));
  box.addChild(new Markdown(content, 0, 0, getMarkdownTheme()));
  return box;
};

function endpointFor(
  ctx: ExtensionContext,
  controlDirectory: string,
  startedAt: string,
): SessionEndpoint {
  const sessionId = ctx.sessionManager.getSessionId();
  return {
    sessionId,
    ...(ctx.sessionManager.getSessionName()?.trim()
      ? { sessionName: ctx.sessionManager.getSessionName()?.trim() }
      : {}),
    cwd: path.resolve(ctx.cwd),
    mode: ctx.mode as "tui" | "rpc",
    pid: process.pid,
    state: ctx.isIdle() ? "idle" : "busy",
    startedAt,
    socketPath: getSessionEndpointPaths(controlDirectory, sessionId).socketPath,
  };
}

async function refreshMetadata(state: RuntimeState): Promise<void> {
  if (!state.context || !state.endpoint) return;
  state.endpoint = endpointFor(
    state.context,
    path.dirname(state.endpoint.socketPath),
    state.endpoint.startedAt,
  );
  await publishSessionEndpoint(
    path.dirname(state.endpoint.socketPath),
    state.endpoint,
  );
}

async function stopRuntime(state: RuntimeState): Promise<void> {
  const endpoint = state.endpoint;
  const server = state.server;
  state.server = undefined;
  state.endpoint = undefined;
  state.context = undefined;
  if (server) await server.stop();
  if (endpoint) {
    await removeSessionEndpoint(
      path.dirname(endpoint.socketPath),
      endpoint.sessionId,
    );
  }
  delete process.env.PI_SESSION_ID;
}

export default function controlExtension(pi: ExtensionAPI): void {
  pi.registerFlag(AUTISTIC_MODE_FLAG, {
    description:
      "Disable the local session-control server and inter-session participation",
    type: "boolean",
    default: false,
  });
  pi.registerMessageRenderer(SESSION_MESSAGE_TYPE, renderSessionMessage);

  const state: RuntimeState = {};

  pi.on("session_start", async (_event, ctx) => {
    await stopRuntime(state);
    state.context = ctx;
    if (pi.getFlag(AUTISTIC_MODE_FLAG) === true) {
      installControlFooter(ctx, state, "[autistic]");
      return;
    }
    if (
      (ctx.mode !== "tui" && ctx.mode !== "rpc") ||
      !ctx.sessionManager.getSessionFile()
    )
      return;
    const controlDirectory = getSessionControlDirectory(getAgentDir());
    await ensureSessionControlDirectory(controlDirectory);
    const endpoint = endpointFor(ctx, controlDirectory, new Date().toISOString());
    await removeSessionEndpoint(controlDirectory, endpoint.sessionId);
    state.context = ctx;
    state.endpoint = endpoint;
    state.server = new SessionControlServer({
      socketPath: endpoint.socketPath,
      session: createControlledSession(pi, state, ctx),
    });
    await state.server.start();
    await publishSessionEndpoint(controlDirectory, endpoint);
    process.env.PI_SESSION_ID = endpoint.sessionId;
    installControlFooter(ctx, state, `[${shortSessionId(endpoint.sessionId)}]`);
  });

  pi.on("session_info_changed", async (_event, ctx) => {
    state.context = ctx;
    await refreshMetadata(state);
  });
  pi.on("agent_start", async (_event, ctx) => {
    state.context = ctx;
    await refreshMetadata(state);
  });
  pi.on("agent_settled", async (_event, ctx) => {
    state.context = ctx;
    await refreshMetadata(state);
  });
  pi.on("model_select", (_event, ctx) => {
    state.context = ctx;
  });
  pi.on("thinking_level_select", (_event, ctx) => {
    state.context = ctx;
  });
  pi.on("session_shutdown", async (_event, ctx) => {
    if (ctx.mode === "tui") ctx.ui.setFooter(undefined);
    await stopRuntime(state);
  });
}
