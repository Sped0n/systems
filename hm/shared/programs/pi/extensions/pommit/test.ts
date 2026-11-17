import assert from "node:assert/strict";
import test from "node:test";
import type {
    ExtensionAPI,
    ExtensionContext,
} from "@earendil-works/pi-coding-agent";

import pommit, {
    buildPommitSystemPrompt,
    formatPommitToolActivity,
} from "./index.ts";

test("buildPommitSystemPrompt directs staged inspection and preserves the optional hint", () => {
    const prompt = buildPommitSystemPrompt("focus on permission changes");
    assert.match(prompt, /rogt status, log, and diff with staged=true/u);
    assert.match(prompt, /grep, find, and ls/u);
    assert.match(prompt, /describe staged changes only/u);
    assert.match(prompt, /Optional user hint: focus on permission changes/u);
});

test("pommit tool activity is a bounded single line", () => {
    assert.equal(
        formatPommitToolActivity("read", {
            path: "hm/shared/programs/pi/default.nix",
        }),
        "→ read hm/shared/programs/pi/default.nix",
    );
    assert.equal(
        formatPommitToolActivity("rogt", { operation: "diff" }),
        "→ rogt diff",
    );
    const activity = formatPommitToolActivity("grep", {
        pattern: `pattern\n${"x".repeat(200)}`,
    });
    assert.equal(activity.includes("\n"), false);
    assert.ok(activity.length <= 129);
    assert.ok(activity.endsWith("..."));
});

test("headless pommit selects only repository inspection tools", async () => {
    const handlers = new Map<string, (...args: any[]) => any>();
    let activeTools: string[] = [];
    const pi = {
        registerFlag() {},
        getFlag: (name: string) => name === "pommit",
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
        pommit(pi);
        await handlers.get("session_start")!({}, ctx);
        assert.deepEqual(activeTools, ["read", "grep", "find", "ls", "rogt"]);
    } finally {
        process.argv = argv;
    }
});
