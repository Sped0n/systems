import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { promises as fs } from "node:fs";
import * as net from "node:net";
import * as path from "node:path";
import test from "node:test";
import {
    ClientControlError,
    ServerControlError,
    UnixSessionControlClient,
} from "./client.ts";
import {
    ensureSessionControlDirectory,
    getSessionEndpointPaths,
    listSessionEndpoints,
    publishSessionEndpoint,
    resolveSessionTarget,
    SessionTargetError,
} from "./discovery.ts";
import {
    ControlProtocolError,
    JsonLineDecoder,
    MAX_RECORD_BYTES,
    encodeJsonLine,
    validateControlRequest,
    validateControlResponse,
    type SendOptions,
    type SessionEndpoint,
} from "./protocol.ts";
import { Runs, visibleMessageText } from "./runs.ts";
import { SessionControlServer, type ControlledSession } from "./server.ts";

const sessionId = "0195f052-ef3b-7aaa-8000-0123456789ab";
const otherId = "0195f052-ef3b-7aaa-8000-fedcba987654";

function protocolError(
    callback: () => unknown,
    code: ControlProtocolError["code"] = "invalid_record",
): void {
    assert.throws(
        callback,
        (error: unknown) =>
            error instanceof ControlProtocolError && error.code === code,
    );
}

test("protocol validates run, capture, send, and wait boundaries", () => {
    const handle = new Runs(sessionId, sessionId).start("run-1", "work").handle;
    for (const request of [
        { id: "r", type: "run", message: "work" },
        { id: "c", type: "capture", lines: 100 },
        { id: "c", type: "capture", lines: 100, run: handle },
        { id: "w", type: "wait", run: handle },
        {
            id: "s",
            type: "send",
            message: "draft",
            draft: true,
            sender: { sessionId },
        },
    ])
        assert.equal(validateControlRequest(request), request);
    for (const request of [
        { id: "x", type: "run", message: " " },
        { id: "x", type: "capture", lines: 0 },
        { id: "x", type: "capture", lines: 1001 },
        { id: "x", type: "wait", run: "invalid" },
        { id: "x", type: "send", message: "ok", draft: "yes" },
        { id: "x", type: "run", message: "ok", surprise: true },
    ])
        protocolError(() => validateControlRequest(request));
});

test("responses preserve success and error invariants", () => {
    const success = {
        id: "s",
        type: "response",
        success: true,
        data: { accepted: true },
    };
    assert.equal(validateControlResponse(success), success);
    protocolError(() =>
        validateControlResponse({ ...success, type: "settled" }),
    );
    protocolError(() =>
        validateControlResponse({ id: "s", type: "response", success: false }),
    );
});

test("JSONL framing handles fragmented UTF-8 and bounded payloads", () => {
    const decoder = new JsonLineDecoder();
    const bytes = Buffer.from('{"message":"héllo"}\n{"ok":true}\n');
    const split = bytes.indexOf(Buffer.from("é")) + 1;
    assert.deepEqual(decoder.push(bytes.subarray(0, split)), []);
    assert.deepEqual(decoder.push(bytes.subarray(split)), [
        { message: "héllo" },
        { ok: true },
    ]);
    decoder.finish();
    protocolError(
        () => encodeJsonLine("é".repeat(MAX_RECORD_BYTES)),
        "record_too_large",
    );
});

async function withDirectory(
    callback: (directory: string, root: string) => Promise<void>,
): Promise<void> {
    const root = await fs.mkdtemp("/tmp/pi-ctl-");
    try {
        await callback(path.join(root, "session-control"), root);
    } finally {
        await fs.rm(root, { recursive: true, force: true });
    }
}

function endpointFor(
    directory: string,
    id: string,
    name: string,
    cwd: string,
): SessionEndpoint {
    return {
        sessionId: id,
        instanceId: sessionId,
        sessionName: name,
        cwd,
        mode: "tui",
        pid: process.pid,
        state: "idle",
        startedAt: "2026-08-20T09:10:42.868Z",
        socketPath: getSessionEndpointPaths(directory, id).socketPath,
    };
}

test("discovery preserves owner-only permissions and rejects ambiguous names", async () => {
    await withDirectory(async (directory, root) => {
        const endpoint = endpointFor(directory, sessionId, "build", root);
        await publishSessionEndpoint(directory, endpoint);
        assert.equal((await fs.stat(directory)).mode & 0o777, 0o700);
        assert.equal(
            (
                await fs.stat(
                    getSessionEndpointPaths(directory, sessionId).metadataPath,
                )
            ).mode & 0o777,
            0o600,
        );
        const listed = await listSessionEndpoints(directory, {
            cwd: root,
            probe: async () => true,
        });
        assert.deepEqual(resolveSessionTarget(listed, "build"), endpoint);
        assert.deepEqual(
            resolveSessionTarget(listed, sessionId.slice(-8)),
            endpoint,
        );
        assert.throws(
            () =>
                resolveSessionTarget(
                    [
                        endpoint,
                        {
                            ...endpoint,
                            sessionId: otherId,
                            sessionName: sessionId.slice(-8),
                        },
                    ],
                    sessionId.slice(-8),
                ),
            SessionTargetError,
        );
        assert.throws(
            () =>
                resolveSessionTarget(
                    [endpoint, endpointFor(directory, otherId, "build", root)],
                    "build",
                ),
            SessionTargetError,
        );
    });
});

class FakeSession implements ControlledSession {
    readonly sent: SendOptions[] = [];
    readonly pasted: string[] = [];
    readonly runs = new Runs(sessionId, sessionId);
    constructor(private readonly endpoint: SessionEndpoint) {}
    describe(): SessionEndpoint {
        return this.endpoint;
    }
    async send(options: SendOptions) {
        if (options.draft) this.pasted.push(options.message);
        else this.sent.push(options);
        return { accepted: true as const, draft: options.draft === true };
    }
    run(id: string, options: SendOptions) {
        return this.runs.start(id, options.message);
    }
    capture(run: string | undefined, _lines: number) {
        return {
            sessionId,
            capturedAt: new Date().toISOString(),
            state: this.runs.busy ? ("busy" as const) : ("idle" as const),
            ...(run
                ? this.runs.capture(run)
                : { text: "Latest result", truncated: false }),
        };
    }
    wait(run: string, signal: AbortSignal) {
        return this.runs.wait(run, signal);
    }
}

async function withServer(
    callback: (
        client: UnixSessionControlClient,
        session: FakeSession,
        root: string,
        server: SessionControlServer,
    ) => Promise<void>,
): Promise<void> {
    await withDirectory(async (directory, root) => {
        await ensureSessionControlDirectory(directory);
        const endpoint = endpointFor(directory, sessionId, "build", root);
        const session = new FakeSession(endpoint);
        const server = new SessionControlServer({
            socketPath: endpoint.socketPath,
            session,
            maxConnections: 4,
        });
        await server.start();
        await publishSessionEndpoint(directory, endpoint);
        try {
            await callback(
                new UnixSessionControlClient({ controlDirectory: directory }),
                session,
                root,
                server,
            );
        } finally {
            await server.stop();
        }
    });
}

test("client and server capture sessions and runs and send drafts", async () => {
    await withServer(async (client, session) => {
        assert.equal((await client.list())[0].sessionName, "build");
        assert.deepEqual(
            await client.send("build", {
                message: "Review",
                sender: { sessionId },
            }),
            { accepted: true, draft: false },
        );
        assert.deepEqual(
            await client.send("build", { message: "draft", draft: true }),
            { accepted: true, draft: true },
        );
        assert.equal((await client.capture("build")).text, "Latest result");
        const run = await client.run("build", { message: "task" });
        assert.equal(
            (await client.capture(run.handle, { run: true })).run?.handle,
            run.handle,
        );
        assert.deepEqual(session.pasted, ["draft"]);
    });
});

test("wait recovers after timeout or interruption without cancelling work", async () => {
    await withServer(async (client, session) => {
        const run = await client.run("build", { message: "task" });
        await assert.rejects(
            client.run("build", { message: "competing" }),
            ServerControlError,
        );
        await assert.rejects(
            client.wait(run.handle, { timeoutMs: 20 }),
            (error: unknown) =>
                error instanceof ClientControlError && error.code === "timeout",
        );
        assert.equal(session.runs.busy, true);
        const controller = new AbortController();
        const abandoned = client.wait(run.handle, {
            signal: controller.signal,
        });
        controller.abort(new Error("stop waiting"));
        await assert.rejects(abandoned, /stop waiting/);
        assert.equal((await client.capture("build")).state, "busy");
        session.runs.update("completed output", false);
        session.runs.finish("completed");
        assert.equal((await client.wait(run.handle)).status, "completed");
        assert.equal(
            (await client.capture(run.handle, { run: true })).text,
            "completed output",
        );
        assert.equal((await client.wait(run.handle)).status, "completed");
    });
});

test("multiple acknowledged waits do not block capture or send", async () => {
    await withServer(async (client, session) => {
        const run = await client.run("build", { message: "task" });
        const controller = new AbortController();
        const waiting = [];
        for (let i = 0; i < 8; i++) {
            const pending = client.wait(run.handle, {
                signal: controller.signal,
            });
            void pending.catch(() => {});
            waiting.push(pending);
            await client.capture("build");
        }
        await client.send("build", { message: "input" });
        session.runs.finish("completed");
        assert.ok(
            (await Promise.all(waiting)).every(
                (result) => result.status === "completed",
            ),
        );
    });
});

test("run results distinguish failure, abortion, expiry, and server replacement", async () => {
    await withServer(async (client, session) => {
        const failed = await client.run("build", { message: "task" });
        session.runs.finish("failed", "provider failed");
        assert.equal(
            (await client.wait(failed.handle)).error,
            "provider failed",
        );
        const aborted = await client.run("build", { message: "task" });
        session.runs.finish("aborted");
        assert.equal((await client.wait(aborted.handle)).status, "aborted");
        for (let i = 0; i < 65; i++) {
            session.runs.start("extra-" + i, "task");
            session.runs.finish("completed");
        }
        await assert.rejects(client.wait(failed.handle), /expired/);
        assert.throws(
            () => new Runs(sessionId, otherId).capture(aborted.handle),
            /another session or server instance/,
        );
    });
});

test("capture excludes hidden reasoning and includes visible tool activity", () => {
    const text = visibleMessageText({
        role: "assistant",
        content: [
            { type: "thinking", thinking: "secret reasoning" },
            { type: "text", text: "answer" },
            { type: "toolCall", name: "read", arguments: { private: "args" } },
        ],
    });
    assert.match(text, /answer/);
    assert.match(text, /tool: read/);
    assert.doesNotMatch(text, /secret reasoning|private/);
    assert.equal(
        visibleMessageText({ role: "system", content: "system prompt" }),
        "",
    );
});

test("client rejects mismatched response IDs and reports server disconnection", async () => {
    await withDirectory(async (directory, root) => {
        await ensureSessionControlDirectory(directory);
        const endpoint = endpointFor(directory, sessionId, "build", root);
        const server = net.createServer((socket) =>
            socket.once("data", () =>
                socket.end(
                    encodeJsonLine({
                        id: "wrong-id",
                        type: "response",
                        success: true,
                        data: {},
                    }),
                ),
            ),
        );
        await new Promise<void>((resolve) =>
            server.listen(endpoint.socketPath, resolve),
        );
        await publishSessionEndpoint(directory, endpoint);
        try {
            await assert.rejects(
                new UnixSessionControlClient({
                    controlDirectory: directory,
                }).capture("build"),
                (error: unknown) =>
                    error instanceof ClientControlError &&
                    error.code === "protocol_error",
            );
        } finally {
            await new Promise<void>((resolve) => server.close(() => resolve()));
        }
    });
    await withServer(async (client, _session, _root, server) => {
        const run = await client.run("build", { message: "task" });
        const waiting = client.wait(run.handle);
        const rejection = assert.rejects(waiting, ClientControlError);
        await client.capture("build");
        await server.stop();
        await rejection;
    });
});

type CliResult = { code: number | null; stdout: string; stderr: string };
async function cli(
    root: string,
    args: string[],
    stdin?: string,
): Promise<CliResult> {
    return await new Promise((resolve, reject) => {
        const child = spawn(
            process.execPath,
            ["--import", "tsx", "scripts/pontrol.ts", ...args],
            {
                env: {
                    ...process.env,
                    PI_CODING_AGENT_DIR: root,
                    PI_SESSION_ID: "",
                },
                stdio: ["pipe", "pipe", "pipe"],
            },
        );
        let stdout = "",
            stderr = "";
        child.stdout.setEncoding("utf8").on("data", (chunk: string) => {
            stdout += chunk;
        });
        child.stderr.setEncoding("utf8").on("data", (chunk: string) => {
            stderr += chunk;
        });
        child.once("error", reject);
        child.once("close", (code) => resolve({ code, stdout, stderr }));
        child.stdin.end(stdin);
    });
}

test("CLI uses positional text, stdin drafts, and explicit run capture", async () => {
    await withServer(async (_client, session, root) => {
        assert.match(
            (await cli(root, ["--help"])).stdout,
            /pontrol capture --run RUN/u,
        );
        assert.equal((await cli(root, ["list", "--json"])).code, 0);
        const sent = await cli(root, [
            "send",
            "build",
            "message text",
            "--json",
        ]);
        assert.equal(sent.code, 0, sent.stderr);
        assert.deepEqual(JSON.parse(sent.stdout), {
            accepted: true,
            draft: false,
        });
        const drafted = await cli(
            root,
            ["send", "build", "--draft", "--stdin", "--json"],
            "draft text",
        );
        assert.equal(drafted.code, 0, drafted.stderr);
        assert.deepEqual(session.pasted, ["draft text"]);
        assert.equal(
            JSON.parse((await cli(root, ["capture", "build", "--json"])).stdout)
                .text,
            "Latest result",
        );
        const run = await cli(root, ["run", "build", "task"]);
        assert.equal(run.code, 0, run.stderr);
        const scoped = await cli(root, [
            "capture",
            "--run",
            run.stdout.trim(),
            "--json",
        ]);
        assert.equal(scoped.code, 0, scoped.stderr);
        assert.equal(JSON.parse(scoped.stdout).run.handle, run.stdout.trim());
        assert.equal(
            (await cli(root, ["capture", "build", "--run", run.stdout.trim()]))
                .code,
            2,
        );
        assert.equal(
            (await cli(root, ["send", "build", "text", "--stdin"], "other"))
                .code,
            2,
        );
        assert.equal(
            (await cli(root, ["send", "build", "--", "--literal"])).code,
            0,
        );
        assert.equal(
            (await cli(root, ["wait", run.stdout.trim(), "--for", "10ms"]))
                .code,
            124,
        );
        session.runs.finish("failed", "failure");
        assert.equal((await cli(root, ["wait", run.stdout.trim()])).code, 1);
    });
});

test("Pi lifecycle correlates runs, captures partial output, and survives client reconnects", async () => {
    const { SessionManager } = await import("@earendil-works/pi-coding-agent");
    const { default: extension } = await import("./index.ts");
    await withDirectory(async (_directory, root) => {
        const previousDir = process.env.PI_CODING_AGENT_DIR;
        const previousId = process.env.PI_SESSION_ID;
        process.env.PI_CODING_AGENT_DIR = root;
        const handlers = new Map<string, (...args: any[]) => any>();
        const manager = SessionManager.create(
            root,
            path.join(root, "sessions"),
        );
        let idle = true;
        let editor: string | undefined = "";
        let submitted: any;
        const pi = {
            registerFlag() {},
            registerMessageRenderer() {},
            getFlag() {
                return false;
            },
            on(name: string, handler: (...args: any[]) => any) {
                handlers.set(name, handler);
            },
            sendMessage(message: any) {
                manager.appendCustomMessageEntry(
                    message.customType,
                    message.content,
                    message.display,
                    message.details,
                );
                submitted = {
                    ...message,
                    role: "custom",
                    timestamp: Date.parse(manager.getLeafEntry()!.timestamp),
                };
            },
        };
        const ctx = {
            cwd: root,
            mode: "tui",
            hasUI: true,
            sessionManager: manager,
            isIdle: () => idle,
            ui: {
                getEditorText: () => editor,
                pasteToEditor: (text: string) => {
                    editor += text;
                },
                setStatus() {},
                notify(message: string) {
                    assert.fail(message);
                },
            },
        };
        const emit = (name: string, event: unknown = {}) =>
            handlers.get(name)!(event, ctx);
        await extension(pi as unknown as Parameters<typeof extension>[0]);
        try {
            await emit("session_start");
            const client = new UnixSessionControlClient({
                controlDirectory: path.join(root, "session-control"),
            });
            const target = manager.getSessionId();
            assert.equal((await client.capture(target)).text, "");
            await client.send(target, { message: "draft", draft: true });
            assert.equal(editor, "draft");
            editor = undefined;
            await assert.rejects(
                client.send(target, {
                    message: "unavailable draft",
                    draft: true,
                }),
                /unavailable/,
            );
            for (const outcome of ["completed", "error", "aborted"] as const) {
                const run = await client.run(target, {
                    message: "task " + outcome,
                });
                await assert.rejects(
                    client.run(target, { message: "overlap" }),
                    /active run/,
                );
                assert.doesNotMatch(
                    (await client.capture(run.handle, { run: true })).text,
                    /partial /,
                );
                await emit("before_agent_start", {
                    messageType: "custom",
                    message: submitted,
                });
                idle = false;
                await emit("agent_start");
                const assistant = {
                    role: "assistant" as const,
                    content: [
                        {
                            type: "thinking" as const,
                            thinking: "hidden reasoning",
                        },
                        { type: "text" as const, text: "partial " + outcome },
                    ],
                    api: "openai-responses" as const,
                    provider: "openai",
                    model: "test",
                    usage: {
                        input: 0,
                        output: 0,
                        cacheRead: 0,
                        cacheWrite: 0,
                        totalTokens: 0,
                        cost: {
                            input: 0,
                            output: 0,
                            cacheRead: 0,
                            cacheWrite: 0,
                            total: 0,
                        },
                    },
                    timestamp: Date.now(),
                    stopReason:
                        outcome === "error"
                            ? ("error" as const)
                            : ("stop" as const),
                    ...(outcome === "error"
                        ? { errorMessage: "provider failed" }
                        : {}),
                };
                await emit("message_update", { message: assistant });
                const partial = await client.capture(run.handle, { run: true });
                assert.match(partial.text, new RegExp("partial " + outcome));
                assert.doesNotMatch(
                    partial.text,
                    /hidden reasoning|sender_info/,
                );
                assert.equal(partial.run?.status, "running");
                assert.equal(partial.state, "busy");
                manager.appendMessage(assistant);
                await emit("message_end", { message: assistant });
                await emit("agent_before_settle", { outcome });
                idle = true;
                await emit("agent_settled", { aborted: outcome === "aborted" });
                const result = await client.wait(run.handle);
                assert.equal(
                    result.status,
                    outcome === "error" ? "failed" : outcome,
                );
                if (outcome === "error")
                    assert.equal(result.error, "provider failed");
                const captured = await client.capture(run.handle, {
                    run: true,
                });
                assert.equal(
                    (captured.text.match(/partial /gu) ?? []).length,
                    1,
                );
                assert.equal(captured.state, "idle");
                if (outcome === "aborted") {
                    await emit("session_start");
                    await assert.rejects(
                        client.wait(run.handle),
                        /another session or server instance/,
                    );
                }
            }
        } finally {
            await emit("session_shutdown");
            if (previousDir === undefined)
                delete process.env.PI_CODING_AGENT_DIR;
            else process.env.PI_CODING_AGENT_DIR = previousDir;
            if (previousId === undefined) delete process.env.PI_SESSION_ID;
            else process.env.PI_SESSION_ID = previousId;
        }
    });
});

test("framing rejects malformed, oversized, and incomplete records", () => {
    protocolError(
        () => new JsonLineDecoder().push(Buffer.from("not-json\n")),
        "malformed_json",
    );
    protocolError(
        () =>
            new JsonLineDecoder().push(
                Buffer.alloc(MAX_RECORD_BYTES + 2, 0x78),
            ),
        "record_too_large",
    );
    const partial = new JsonLineDecoder();
    partial.push(Buffer.from('{"id":'));
    protocolError(() => partial.finish(), "malformed_json");
    for (const sender of [
        { sessionId: "invalid" },
        { sessionId, extra: true },
        { sessionId, sessionName: " " },
    ]) {
        protocolError(() =>
            validateControlRequest({
                id: "s",
                type: "send",
                message: "ok",
                sender,
            }),
        );
    }
});

test("discovery ignores malformed metadata and removes stale endpoints", async () => {
    await withDirectory(async (directory, root) => {
        const endpoint = endpointFor(directory, sessionId, "build", root);
        await publishSessionEndpoint(directory, endpoint);
        const metadata = getSessionEndpointPaths(
            directory,
            sessionId,
        ).metadataPath;
        await fs.writeFile(
            metadata,
            JSON.stringify({ ...endpoint, socketPath: "/unexpected/socket" }),
        );
        assert.deepEqual(
            await listSessionEndpoints(directory, { probe: async () => true }),
            [],
        );
        await publishSessionEndpoint(directory, endpoint);
        assert.deepEqual(
            await listSessionEndpoints(directory, { probe: async () => false }),
            [],
        );
        await assert.rejects(fs.stat(metadata), { code: "ENOENT" });
    });
});
