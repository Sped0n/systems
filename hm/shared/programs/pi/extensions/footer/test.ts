import assert from "node:assert/strict";
import test from "node:test";
import { stripVTControlCharacters } from "node:util";
import {
    initTheme,
    SessionManager,
    type ExtensionAPI,
    type ExtensionContext,
    type Theme,
} from "@earendil-works/pi-coding-agent";
import { visibleWidth } from "@earendil-works/pi-tui";
import controlExtension from "../control/index.ts";
import openaiExtension from "../openai/index.ts";
import footerExtension, { FAST_MODE_STATUS } from "./index.ts";

type Handler = (event: unknown, ctx: ExtensionContext) => unknown;
type Factory = NonNullable<Parameters<ExtensionContext["ui"]["setFooter"]>[0]>;

initTheme("dark");

async function harness(footerFirst: boolean) {
    const manager = SessionManager.inMemory();
    manager.appendCustomEntry("openai-fast-mode", { enabled: true });
    const statuses = new Map<string, string>([["other", "Other status"]]);
    const handlers = new Map<string, Handler[]>();
    let factory: Factory | undefined;
    const ctx = {
        mode: "tui",
        model: {
            id: "gpt-6.1-sol",
            api: "openai-responses",
            provider: "circe-responses",
            reasoning: true,
            contextWindow: 272000,
        },
        thinkingLevel: "medium",
        sessionManager: manager,
        getContextUsage: () => undefined,
        ui: {
            setFooter: (value: Factory | undefined) => {
                factory = value;
            },
            setStatus: (key: string, value: string | undefined) => {
                if (value === undefined) statuses.delete(key);
                else statuses.set(key, value);
            },
        },
    } as unknown as ExtensionContext;
    const pi = {
        on: (name: string, handler: Handler) => {
            const list = handlers.get(name) ?? [];
            list.push(handler);
            handlers.set(name, list);
        },
        registerFlag: () => {},
        registerMessageRenderer: () => {},
        registerCommand: () => {},
        getFlag: () => true,
    } as unknown as ExtensionAPI;
    const factories = footerFirst
        ? [footerExtension, controlExtension, openaiExtension]
        : [controlExtension, openaiExtension, footerExtension];
    for (const extension of factories) extension(pi);
    const emit = async (name: string) => {
        for (const handler of handlers.get(name) ?? []) await handler({}, ctx);
    };
    await emit("session_start");
    assert.ok(factory);
    const theme = {
        fg: (color: string, text: string) =>
            `\x1b[${color === "accent" ? "35" : "90"}m${text}\x1b[0m`,
        getFgAnsi: () => "\x1b[90m",
    } as unknown as Theme;
    const footer = factory(
        { requestRender: () => {} } as Parameters<Factory>[0],
        theme,
        {
            getGitBranch: () => "main",
            getAvailableProviderCount: () => 2,
            getExtensionStatuses: () => statuses,
            onBranchChange: () => () => {},
        },
    );
    return {
        ctx,
        statuses,
        footer,
        emit,
    };
}

test("footer preserves the control marker, highlights fast, and keeps other statuses in either load order", async () => {
    for (const footerFirst of [true, false]) {
        const h = await harness(footerFirst);
        const lines = h.footer.render(120);
        const plain = lines.map(stripVTControlCharacters);
        assert.match(plain[0]!, /\[autistic\]$/u);
        assert.match(plain[1]!, /gpt-6\.1-sol \(fast\) • medium$/u);
        assert.doesNotMatch(plain[1]!, /\(circe-responses\)/u);
        assert.ok(lines[1]!.includes("\x1b[35m(fast)\x1b[0m\x1b[90m • medium"));
        assert.deepEqual(plain.slice(2), ["Other status"]);
        assert.equal(h.ctx.model?.id, "gpt-6.1-sol");

        h.statuses.delete(FAST_MODE_STATUS);
        const withoutFast = stripVTControlCharacters(h.footer.render(120)[1]!);
        assert.match(withoutFast, /gpt-6\.1-sol • medium$/u);
        assert.doesNotMatch(withoutFast, /\(fast\)|\(circe-responses\)/u);
        assert.equal(h.ctx.model?.provider, "circe-responses");
        h.footer.dispose?.();
        await h.emit("session_shutdown");
    }
});

test("footer lines stay within narrow terminal widths", async () => {
    const h = await harness(true);
    for (const width of [1, 5, 10, 20, 40, 80]) {
        for (const line of h.footer.render(width)) {
            assert.ok(
                visibleWidth(line) <= width,
                `${width}: ${stripVTControlCharacters(line)}`,
            );
        }
    }
    h.footer.dispose?.();
    await h.emit("session_shutdown");
});
