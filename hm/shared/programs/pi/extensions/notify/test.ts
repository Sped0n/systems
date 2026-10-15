import assert from "node:assert/strict";
import { PassThrough } from "node:stream";
import test, { type TestContext } from "node:test";
import type {
    ExtensionAPI,
    ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import notify from "./index.ts";

type Handler = (event: unknown, ctx: ExtensionContext) => void;

function harness(t: TestContext, tmux = false) {
    const stdin = new PassThrough();
    t.mock.getter(process, "stdin", () => stdin);
    t.after(() => stdin.destroy());
    const previousTmux = process.env.TMUX;
    if (tmux) process.env.TMUX = "/tmp/tmux-test/default,123,0";
    else delete process.env.TMUX;
    t.after(() => {
        if (previousTmux === undefined) delete process.env.TMUX;
        else process.env.TMUX = previousTmux;
    });

    const output: string[] = [];
    t.mock.method(process.stdout, "write", (chunk: string) => {
        output.push(chunk);
        return true;
    });
    const handlers = new Map<string, Handler>();
    const ctx = {
        mode: "tui",
        cwd: "/projects/example",
    } as unknown as ExtensionContext;
    notify({
        on(name: string, handler: Handler) {
            handlers.set(name, handler);
        },
    } as unknown as ExtensionAPI);
    t.after(() => handlers.get("session_shutdown")?.({}, ctx));
    return {
        ctx,
        output,
        emit(name: string, event: unknown = {}) {
            handlers.get(name)?.(event, ctx);
        },
        input(data: string | Buffer) {
            stdin.write(data);
        },
    };
}

test("only non-aborted settlement while unfocused sends a notification", (t) => {
    const h = harness(t);
    h.emit("session_start");
    assert.deepEqual(h.output.splice(0), ["\x1b[?1004h"]);
    h.emit("agent_settled", { aborted: false });
    assert.deepEqual(h.output, []);
    h.input("ordinary input");
    h.input("\x1b[O");
    h.emit("agent_end");
    h.emit("agent_settled", { aborted: true });
    assert.deepEqual(h.output, []);
    h.emit("agent_settled", { aborted: false });
    assert.deepEqual(h.output.splice(0), [
        "\x1b]777;notify;Pi · example;Waiting for input\x07",
    ]);
    h.input("\x1b[I");
    h.emit("agent_settled", { aborted: false });
    assert.deepEqual(h.output, []);
});

test("focus reports survive chunk boundaries and remain visible to other stdin listeners", (t) => {
    const h = harness(t);
    const received: Array<string | Buffer> = [];
    const observe = (chunk: string | Buffer) => received.push(chunk);
    process.stdin.on("data", observe);
    t.after(() => process.stdin.off("data", observe));
    h.emit("session_start");
    h.output.length = 0;
    const chunks = [Buffer.from("keys\x1b"), Buffer.from("["), "O"];
    for (const chunk of chunks) h.input(chunk);
    h.emit("agent_settled", { aborted: false });
    assert.deepEqual(h.output.splice(0), [
        "\x1b]777;notify;Pi · example;Waiting for input\x07",
    ]);
    assert.deepEqual(
        received.map((chunk) => chunk.toString()),
        chunks.map((chunk) => chunk.toString()),
    );
    h.input("\x1b[O\x1b[I");
    h.emit("agent_settled", { aborted: false });
    assert.deepEqual(h.output, []);
});

test("tmux notifications use passthrough and cannot inject directory-name escapes", (t) => {
    const h = harness(t, true);
    h.ctx.cwd = "/projects/bad;\x07\x1b\x9cname";
    h.emit("session_start");
    h.output.length = 0;
    h.input("\x1b[O");
    h.emit("agent_settled", { aborted: false });
    assert.deepEqual(h.output, [
        "\x1bPtmux;\x1b\x1b]777;notify;Pi · bad    name;Waiting for input\x07\x1b\\",
    ]);
});

test("shutdown removes focus tracking and restarting defaults to focused", (t) => {
    const h = harness(t);
    h.emit("session_start");
    h.input("\x1b[O");
    h.output.length = 0;
    h.emit("session_shutdown");
    h.emit("session_shutdown");
    h.input("\x1b[O");
    h.emit("agent_settled", { aborted: false });
    assert.deepEqual(h.output.splice(0), ["\x1b[?1004l"]);
    h.emit("session_start");
    h.emit("agent_settled", { aborted: false });
    assert.deepEqual(h.output, ["\x1b[?1004h"]);
});

test("noninteractive modes neither track focus nor write terminal escapes", (t) => {
    const h = harness(t);
    for (const mode of ["rpc", "json", "print"] as const) {
        h.ctx.mode = mode;
        h.emit("session_start");
        h.input("\x1b[O");
        h.emit("agent_settled", { aborted: false });
        h.emit("session_shutdown");
    }
    assert.deepEqual(h.output, []);
});
