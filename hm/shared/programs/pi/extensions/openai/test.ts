import assert from "node:assert/strict";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import * as path from "node:path";
import test from "node:test";
import {
    createExtensionRuntime,
    ExtensionRunner,
    SessionManager,
    type Extension,
    type ModelRegistry,
    type ExtensionAPI,
    type ExtensionCommandContext,
    type ExtensionContext,
    type RegisteredCommand,
} from "@earendil-works/pi-coding-agent";
import { FAST_MODE_STATUS } from "../footer/index.ts";
import openaiExtension from "./index.ts";

const gpt = {
    id: "gpt-6.1-sol",
    api: "openai-responses",
} as NonNullable<ExtensionContext["model"]>;

type Handler = (event: unknown, ctx: ExtensionContext) => unknown;

function harness(manager = SessionManager.inMemory()) {
    const handlers = new Map<string, Handler>();
    const statuses = new Map<string, string>();
    let command: RegisteredCommand | undefined;
    openaiExtension({
        on: (name: string, handler: Handler) => handlers.set(name, handler),
        registerCommand: (_name: string, definition: RegisteredCommand) => {
            command = definition;
        },
        appendEntry: (type: string, data: unknown) => {
            manager.appendCustomEntry(type, data);
        },
    } as unknown as ExtensionAPI);
    const ctx = {
        model: gpt,
        sessionManager: manager,
        // Commands must work without waiting for a running agent to settle.
        isIdle: () => false,
        ui: {
            setStatus: (key: string, value: string | undefined) => {
                if (value === undefined) statuses.delete(key);
                else statuses.set(key, value);
            },
            notify: () => {},
        },
    } as unknown as ExtensionCommandContext;
    const emit = async (name: string) => {
        const handler = handlers.get(name);
        assert.ok(handler);
        return handler({}, ctx);
    };
    // Exercise Pi's dispatcher so a hook-result contract change cannot be
    // hidden by a test helper that unwraps the wrong return shape.
    const runner = new ExtensionRunner(
        [
            {
                path: "openai",
                handlers: new Map(
                    [...handlers].map(([name, handler]) => [name, [handler]]),
                ),
            } as Extension,
        ],
        createExtensionRuntime(),
        process.cwd(),
        manager,
        {} as ModelRegistry,
    );
    runner.createContext = () => ctx;
    return {
        ctx,
        statuses,
        emit,
        toggle: async () => {
            assert.ok(command);
            await command.handler("", ctx);
        },
        request: async (payload: Record<string, unknown>) => {
            return (await runner.emitBeforeProviderRequest(payload)) as Record<
                string,
                unknown
            >;
        },
    };
}

test("GPT Responses defaults preserve effort and structured output without mutating the input", async () => {
    const h = harness();
    await h.emit("session_start");
    const payload = {
        model: "gpt-6.1-sol",
        reasoning: { effort: "medium", summary: "auto" },
        text: {
            format: { type: "json_schema", name: "result" },
            verbosity: "high",
        },
        service_tier: "flex",
        instructions: "Keep this",
    };
    const before = structuredClone(payload);
    assert.deepEqual(await h.request(payload), {
        ...payload,
        reasoning: { effort: "medium", summary: "concise" },
        text: { ...payload.text, verbosity: "low" },
    });
    assert.deepEqual(payload, before);
    assert.deepEqual(await h.request({ instructions: "No reasoning" }), {
        instructions: "No reasoning",
        text: { verbosity: "low" },
    });
});

test("a toggle while busy affects subsequent requests, not the in-flight payload", async () => {
    const h = harness();
    await h.emit("session_start");
    const input = { reasoning: { effort: "medium" } };
    const inFlight = await h.request(input);
    assert.equal(inFlight.service_tier, undefined);
    await h.toggle();
    assert.equal(h.statuses.get(FAST_MODE_STATUS), "(fast)");
    const priority = await h.request(input);
    assert.equal(priority.service_tier, "priority");
    assert.equal(inFlight.service_tier, undefined);
    await h.toggle();
    assert.equal(h.statuses.has(FAST_MODE_STATUS), false);
    assert.equal((await h.request(input)).service_tier, undefined);
    assert.equal(priority.service_tier, "priority");
});

test("unsupported models suspend fast mode and cannot toggle it; GPT Codex restores it", async () => {
    const h = harness();
    await h.toggle();
    for (const model of [
        { ...gpt, id: "claude-sonnet", api: "anthropic-messages" },
        { ...gpt, api: "openai-completions" },
    ]) {
        h.ctx.model = model as typeof gpt;
        await h.emit("model_select");
        assert.equal(h.statuses.has(FAST_MODE_STATUS), false);
        const payload = {
            reasoning: { effort: "high" },
            text: { verbosity: "high" },
        };
        assert.equal(await h.request(payload), payload);
        const count = h.ctx.sessionManager.getBranch().length;
        await h.toggle();
        assert.equal(h.ctx.sessionManager.getBranch().length, count);
    }
    h.ctx.model = { ...gpt, api: "openai-codex-responses" };
    await h.emit("model_select");
    assert.equal(h.statuses.get(FAST_MODE_STATUS), "(fast)");
    assert.equal((await h.request({})).service_tier, "priority");
});

test("resume and branch navigation restore the saved preference; new sessions start off", async (t) => {
    const directory = await mkdtemp(path.join(tmpdir(), "pi-openai-"));
    t.after(() => rm(directory, { recursive: true, force: true }));
    const manager = SessionManager.create(directory, directory);
    manager.appendMessage({
        role: "user",
        content: "Hello",
        timestamp: Date.now(),
    });
    const first = harness(manager);
    await first.toggle();
    const on = manager.getLeafId()!;
    await first.toggle();
    const off = manager.getLeafId()!;

    const restored = SessionManager.open(manager.getSessionFile()!);
    const resumed = harness(restored);
    await resumed.emit("session_start");
    assert.equal((await resumed.request({})).service_tier, undefined);
    restored.branch(on);
    await resumed.emit("session_tree");
    assert.equal((await resumed.request({})).service_tier, "priority");
    restored.appendMessage({
        role: "user",
        content: "On this branch",
        timestamp: Date.now(),
    });
    const restarted = harness(SessionManager.open(restored.getSessionFile()!));
    await restarted.emit("session_start");
    assert.equal(restarted.statuses.get(FAST_MODE_STATUS), "(fast)");
    restored.branch(off);
    restarted.ctx.sessionManager = restored;
    await restarted.emit("session_tree");
    assert.equal((await restarted.request({})).service_tier, undefined);

    restarted.ctx.sessionManager = SessionManager.inMemory();
    await restarted.emit("session_start");
    assert.equal(restarted.statuses.has(FAST_MODE_STATUS), false);
    assert.equal((await restarted.request({})).service_tier, undefined);
});
