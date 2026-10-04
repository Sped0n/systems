import assert from "node:assert/strict";
import test from "node:test";
import type {
    ExtensionAPI,
    ExtensionContext,
} from "@earendil-works/pi-coding-agent";

import pcommit, {
    buildPcommitSystemPrompt,
    formatPcommitToolActivity,
} from "./index.ts";

test("buildPcommitSystemPrompt directs staged inspection and preserves the optional hint", () => {
    const prompt = buildPcommitSystemPrompt("focus on permission changes");
    assert.match(prompt, /rogt status, log, and diff with staged=true/u);
    assert.match(prompt, /grep, find, and ls/u);
    assert.match(prompt, /describe staged changes only/u);
    assert.match(prompt, /Optional user hint: focus on permission changes/u);
});

test("pcommit tool activity is a bounded single line", () => {
    assert.equal(
        formatPcommitToolActivity("read", {
            path: "hm/shared/programs/pi/default.nix",
        }),
        "→ read hm/shared/programs/pi/default.nix",
    );
    assert.equal(
        formatPcommitToolActivity("rogt", { operation: "diff" }),
        "→ rogt diff",
    );
    const activity = formatPcommitToolActivity("grep", {
        pattern: `pattern\n${"x".repeat(200)}`,
    });
    assert.equal(activity.includes("\n"), false);
    assert.ok(activity.length <= 129);
    assert.ok(activity.endsWith("..."));
});

test("headless pcommit selects only repository inspection tools", async () => {
    const handlers = new Map<string, (...args: any[]) => any>();
    let activeTools: string[] = [];
    const pi = {
        registerFlag() {},
        getFlag: (name: string) => name === "pcommit",
        on: (name: string, handler: (...args: any[]) => any) =>
            handlers.set(name, handler),
        exec: async (_command: string, args: string[]) => ({
            code: args[0] === "diff" ? 1 : 0,
            stdout: "true",
            stderr: "",
        }),
        setActiveTools: (tools: string[]) => {
            activeTools = tools;
        },
    } as unknown as ExtensionAPI;
    const ctx = {
        cwd: process.cwd(),
        hasUI: false,
        shutdown() {
            throw new Error("Unexpected shutdown");
        },
    } as unknown as ExtensionContext;
    const argv = [...process.argv];
    process.argv.push("--no-session");
    try {
        pcommit(pi);
        await handlers.get("session_start")!({}, ctx);
        assert.deepEqual(activeTools, ["read", "grep", "find", "ls", "rogt"]);
    } finally {
        process.argv = argv;
    }
});
