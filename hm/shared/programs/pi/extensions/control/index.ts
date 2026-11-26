import { randomUUID } from "node:crypto";
import {
    CAPTURE_CHAR_LIMIT,
    RunError,
    Runs,
    visibleMessageText,
} from "./runs.ts";
import type {
    ExtensionAPI,
    ExtensionContext,
    MessageRenderer,
} from "@earendil-works/pi-coding-agent";
import { getAgentDir, getMarkdownTheme } from "@earendil-works/pi-coding-agent";
import type { TextContent } from "@earendil-works/pi-ai";
import { Box, Markdown, Spacer, Text } from "@earendil-works/pi-tui";
import * as path from "node:path";
import { SESSION_MARKER_STATUS } from "../ui/footer.ts";

import {
    ensureSessionControlDirectory,
    getSessionControlDirectory,
    getSessionEndpointPaths,
    publishSessionEndpoint,
    removeSessionEndpoint,
} from "./discovery.ts";
import {
    shortSessionId,
    type CaptureResult,
    type SenderMetadata,
    type SendOptions,
    type SessionEndpoint,
} from "./protocol.ts";
import { SessionControlServer, type ControlledSession } from "./server.ts";

const AUTISTIC_MODE_FLAG = "autistic-mode";
const SESSION_MESSAGE_TYPE = "session-message";

interface RuntimeState {
    server?: SessionControlServer;
    context?: ExtensionContext;
    endpoint?: SessionEndpoint;
    runs?: Runs;
    liveMessage?: unknown;
    outcome?: "completed" | "aborted" | "error";
    errorMessage?: string;
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

function messageFromEntry(
    entry: ReturnType<ExtensionContext["sessionManager"]["getBranch"]>[number],
): unknown {
    if (entry.type === "message") return entry.message;
    if (entry.type === "custom_message")
        return {
            ...entry,
            role: "custom",
            timestamp: Date.parse(entry.timestamp),
        };
    return undefined;
}

function entryRunHandle(value: unknown): string | undefined {
    if (typeof value !== "object" || value === null) return undefined;
    const message = value as Record<string, unknown>;
    const details = message.details;
    if (
        message.customType !== SESSION_MESSAGE_TYPE ||
        typeof details !== "object" ||
        details === null
    )
        return undefined;
    const handle = (details as Record<string, unknown>).runHandle;
    return typeof handle === "string" ? handle : undefined;
}

function snapshot(
    ctx: ExtensionContext,
    liveMessage: unknown,
    run?: string,
): { text: string; truncated: boolean } | undefined {
    const messages = ctx.sessionManager
        .getBranch()
        .map(messageFromEntry)
        .filter((message) => message !== undefined);
    let start = 0;
    if (run) {
        start = messages.findIndex(
            (message) => entryRunHandle(message) === run,
        );
        if (start < 0) return undefined;
    }
    if (liveMessage && !ctx.isIdle()) {
        const live = liveMessage as { timestamp?: number; role?: string };
        const last = messages.at(-1) as
            | { timestamp?: number; role?: string }
            | undefined;
        if (
            !last ||
            last.timestamp !== live.timestamp ||
            last.role !== live.role
        )
            messages.push(liveMessage);
    }
    const chunks: string[] = [];
    let size = 0;
    let truncated = false;
    for (let i = messages.length - 1; i >= start; i--) {
        const text = visibleMessageText(messages[i]);
        if (!text) continue;
        chunks.unshift(text.slice(-CAPTURE_CHAR_LIMIT));
        size += text.length + 2;
        if (size > CAPTURE_CHAR_LIMIT) {
            truncated = true;
            break;
        }
    }
    return { text: chunks.join("\n\n").slice(-CAPTURE_CHAR_LIMIT), truncated };
}

function tail(
    text: string,
    lines: number,
): { text: string; truncated: boolean } {
    const all = text.split("\n");
    return {
        text: all.slice(-lines).join("\n"),
        truncated: all.length > lines,
    };
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
    const runs = state.runs!;
    const getLiveMessage = () => state.liveMessage;
    const inject = (
        message: string,
        sender?: SenderMetadata,
        runHandle?: string,
    ) => {
        const busy = !ctx.isIdle();
        pi.sendMessage(
            {
                customType: SESSION_MESSAGE_TYPE,
                content: message + senderSuffix(sender),
                display: true,
                details: { sender, ...(runHandle ? { runHandle } : {}) },
            },
            busy ? { deliverAs: "steer" } : { triggerTurn: true },
        );
    };
    const updateRun = () => {
        if (!runs.activeHandle) return;
        const captured = snapshot(ctx, getLiveMessage(), runs.activeHandle);
        if (captured) runs.update(captured.text, captured.truncated);
    };
    return {
        describe: () => state.endpoint!,
        send(options) {
            if (options.draft) {
                if (!ctx.hasUI)
                    throw new RunError(
                        "draft_unavailable",
                        "Target session has no editor",
                    );
                if (ctx.ui.getEditorText() === undefined)
                    throw new RunError(
                        "draft_unavailable",
                        "Target editor is unavailable",
                    );
                ctx.ui.pasteToEditor(options.message);
            } else {
                if (runs.activeHandle && ctx.isIdle())
                    throw new RunError(
                        "session_busy",
                        "A submitted run is starting",
                    );
                inject(options.message, options.sender);
            }
            return { accepted: true, draft: options.draft === true };
        },
        run(id, options) {
            if (!ctx.isIdle())
                throw new RunError(
                    "session_busy",
                    "Run requires an idle session; use send to steer busy work",
                );
            const result = runs.start(id, options.message);
            try {
                inject(options.message, options.sender, result.handle);
            } catch (error) {
                runs.finish(
                    "failed",
                    error instanceof Error ? error.message : String(error),
                );
                throw error;
            }
            return result;
        },
        capture(run, lines): CaptureResult {
            updateRun();
            const captured = run
                ? runs.capture(run)
                : (snapshot(ctx, getLiveMessage()) ?? {
                      text: "",
                      truncated: false,
                  });
            const sliced = tail(captured.text, lines);
            return {
                sessionId: ctx.sessionManager.getSessionId(),
                state: !ctx.isIdle() || runs.busy ? "busy" : "idle",
                capturedAt: new Date().toISOString(),
                ...captured,
                text: sliced.text,
                truncated: captured.truncated || sliced.truncated,
            };
        },
        wait(handle, signal) {
            return runs.wait(handle, signal);
        },
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
    instanceId: string,
    busy = false,
): SessionEndpoint {
    const sessionId = ctx.sessionManager.getSessionId();
    return {
        sessionId,
        instanceId,
        ...(ctx.sessionManager.getSessionName()?.trim()
            ? { sessionName: ctx.sessionManager.getSessionName()?.trim() }
            : {}),
        cwd: path.resolve(ctx.cwd),
        mode: ctx.mode as "tui" | "rpc",
        pid: process.pid,
        state: ctx.isIdle() && !busy ? "idle" : "busy",
        startedAt,
        socketPath: getSessionEndpointPaths(controlDirectory, sessionId)
            .socketPath,
    };
}

async function refreshMetadata(state: RuntimeState): Promise<void> {
    if (!state.context || !state.endpoint) return;
    state.endpoint = endpointFor(
        state.context,
        path.dirname(state.endpoint.socketPath),
        state.endpoint.startedAt,
        state.endpoint.instanceId,
        state.runs?.busy,
    );
    await publishSessionEndpoint(
        path.dirname(state.endpoint.socketPath),
        state.endpoint,
    );
}

async function stopRuntime(state: RuntimeState): Promise<void> {
    const endpoint = state.endpoint;
    const server = state.server;
    state.runs?.finish("aborted", "Session control stopped");
    state.runs = undefined;
    state.liveMessage = undefined;
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
        ctx.ui.setStatus(SESSION_MARKER_STATUS, undefined);
        if (pi.getFlag(AUTISTIC_MODE_FLAG) === true) {
            ctx.ui.setStatus(SESSION_MARKER_STATUS, "[autistic]");
            return;
        }
        if (
            (ctx.mode !== "tui" && ctx.mode !== "rpc") ||
            !ctx.sessionManager.getSessionFile()
        )
            return;
        const controlDirectory = getSessionControlDirectory(getAgentDir());
        await ensureSessionControlDirectory(controlDirectory);
        const endpoint = endpointFor(
            ctx,
            controlDirectory,
            new Date().toISOString(),
            randomUUID(),
        );
        await removeSessionEndpoint(controlDirectory, endpoint.sessionId);
        state.context = ctx;
        state.endpoint = endpoint;
        state.runs = new Runs(endpoint.sessionId, endpoint.instanceId);
        state.server = new SessionControlServer({
            socketPath: endpoint.socketPath,
            session: createControlledSession(pi, state, ctx),
        });
        await state.server.start();
        await publishSessionEndpoint(controlDirectory, endpoint);
        process.env.PI_SESSION_ID = endpoint.sessionId;
        ctx.ui.setStatus(
            SESSION_MARKER_STATUS,
            `[${shortSessionId(endpoint.sessionId)}]`,
        );
    });

    pi.on("session_info_changed", async (_event, ctx) => {
        state.context = ctx;
        await refreshMetadata(state);
    });
    pi.on("before_agent_start", (event) => {
        state.liveMessage = undefined;
        if (event.messageType !== "custom") return;
        const handle = entryRunHandle(event.message);
        if (handle) state.runs?.began(handle);
    });
    pi.on("agent_start", async (_event, ctx) => {
        state.liveMessage = undefined;
        state.outcome = "completed";
        state.errorMessage = undefined;
        state.context = ctx;
        await refreshMetadata(state);
    });
    pi.on("message_update", (event) => {
        state.liveMessage = event.message;
    });
    pi.on("message_end", (event) => {
        state.liveMessage = event.message;
        if (
            event.message.role === "assistant" &&
            event.message.stopReason === "error"
        )
            state.errorMessage = event.message.errorMessage;
    });
    pi.on("agent_before_settle", (event) => {
        state.outcome = event.outcome;
    });
    pi.on("agent_settled", async (event, ctx) => {
        const captured = state.runs?.activeHandle
            ? snapshot(ctx, state.liveMessage, state.runs.activeHandle)
            : undefined;
        if (captured) state.runs?.update(captured.text, captured.truncated);
        state.runs?.finish(
            event.aborted || state.outcome === "aborted"
                ? "aborted"
                : state.outcome === "error"
                  ? "failed"
                  : "completed",
            state.outcome === "error"
                ? (state.errorMessage ?? "Agent failed")
                : undefined,
        );
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
        ctx.ui.setStatus(SESSION_MARKER_STATUS, undefined);
        await stopRuntime(state);
    });
}
