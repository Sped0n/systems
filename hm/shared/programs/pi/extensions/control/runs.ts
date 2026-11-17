import { makeRunHandle, parseRunHandle, type RunResult } from "./protocol.ts";

export const CAPTURE_CHAR_LIMIT = 12_000;
const COMPLETED_RUN_LIMIT = 64;

export class RunError extends Error {
    constructor(
        readonly code: string,
        message: string,
    ) {
        super(message);
        this.name = "RunError";
    }
}

type StoredRun = {
    result: RunResult;
    text: string;
    truncated: boolean;
    waiters: Set<(result: RunResult) => void>;
};

/** Run records outlive clients, but not their owning Pi server instance. */
export class Runs {
    private readonly records = new Map<string, StoredRun>();
    private active?: StoredRun;

    constructor(
        private readonly sessionId: string,
        private readonly instanceId: string,
    ) {}

    get busy(): boolean {
        return this.active !== undefined;
    }

    start(id: string, message: string): RunResult {
        const handle = makeRunHandle(this.sessionId, this.instanceId, id);
        if (this.records.has(handle))
            throw new RunError(
                "duplicate_run",
                "Submission ID has already been used",
            );
        if (this.active)
            throw new RunError(
                "session_busy",
                "Session already has an active run",
            );
        const record: StoredRun = {
            result: {
                handle,
                status: "starting",
                startedAt: new Date().toISOString(),
            },
            text: `[user]\n${message}`.slice(-CAPTURE_CHAR_LIMIT),
            truncated: message.length + 7 > CAPTURE_CHAR_LIMIT,
            waiters: new Set(),
        };
        this.records.set(handle, record);
        this.active = record;
        return { ...record.result };
    }

    began(handle: string): void {
        if (this.active?.result.handle === handle)
            this.active.result.status = "running";
    }

    update(text: string, truncated: boolean): void {
        if (!this.active) return;
        this.active.text = text.slice(-CAPTURE_CHAR_LIMIT);
        this.active.truncated = truncated || text.length > CAPTURE_CHAR_LIMIT;
    }

    finish(status: "completed" | "failed" | "aborted", error?: string): void {
        const record = this.active;
        if (!record) return;
        record.result = {
            ...record.result,
            status,
            finishedAt: new Date().toISOString(),
            ...(error ? { error: error.slice(0, 2000) } : {}),
        };
        this.active = undefined;
        for (const resolve of record.waiters) resolve({ ...record.result });
        record.waiters.clear();
        while (this.records.size > COMPLETED_RUN_LIMIT) {
            const oldest = this.records.keys().next().value;
            if (oldest === undefined) break;
            this.records.delete(oldest);
        }
    }

    get activeHandle(): string | undefined {
        return this.active?.result.handle;
    }

    capture(handle: string): {
        run: RunResult;
        text: string;
        truncated: boolean;
    } {
        const record = this.lookup(handle);
        return {
            run: { ...record.result },
            text: record.text,
            truncated: record.truncated,
        };
    }

    wait(handle: string, signal: AbortSignal): Promise<RunResult> {
        const record = this.lookup(handle);
        if (signal.aborted) return Promise.reject(signal.reason);
        if (record.result.finishedAt)
            return Promise.resolve({ ...record.result });
        return new Promise((resolve, reject) => {
            const complete = (result: RunResult) => {
                signal.removeEventListener("abort", abort);
                resolve(result);
            };
            const abort = () => {
                record.waiters.delete(complete);
                reject(signal.reason);
            };
            record.waiters.add(complete);
            signal.addEventListener("abort", abort, { once: true });
        });
    }

    private lookup(handle: string): StoredRun {
        const parsed = parseRunHandle(handle);
        if (
            parsed.sessionId !== this.sessionId ||
            parsed.instanceId !== this.instanceId
        )
            throw new RunError(
                "run_unavailable",
                "Run belongs to another session or server instance",
            );
        const record = this.records.get(handle);
        if (!record)
            throw new RunError(
                "run_unavailable",
                "Run is unknown or its result has expired",
            );
        return record;
    }
}

/** Capture visible text only. Never serialize model thinking or raw session entries. */
export function visibleMessageText(value: unknown): string {
    if (typeof value !== "object" || value === null) return "";
    const message = value as Record<string, unknown>;
    if (
        !["user", "assistant", "toolResult", "custom"].includes(
            String(message.role),
        )
    )
        return "";
    if (message.role === "custom" && message.display !== true) return "";
    const content = message.content;
    const text =
        typeof content === "string"
            ? content
            : Array.isArray(content)
              ? content
                    .flatMap((part: unknown) => {
                        if (typeof part !== "object" || part === null)
                            return [];
                        const block = part as Record<string, unknown>;
                        if (
                            block.type === "text" &&
                            typeof block.text === "string"
                        )
                            return [block.text];
                        if (
                            block.type === "toolCall" &&
                            typeof block.name === "string"
                        )
                            return [`[tool: ${block.name}]`];
                        return [];
                    })
                    .join("\n")
              : "";
    const visible =
        message.role === "custom"
            ? text.replace(/\n*<sender_info>[\s\S]*?<\/sender_info>\s*$/u, "")
            : text;
    return visible
        ? `[${message.role === "toolResult" ? "tool" : message.role}]\n${visible}`
        : "";
}
