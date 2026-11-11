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
import { FAST_MODE_STATUS } from "./footer.ts";
import uiExtension from "./index.ts";

type Handler = (event: unknown, ctx: ExtensionContext) => unknown;
type EditorFactory = NonNullable<
    Parameters<ExtensionContext["ui"]["setEditorComponent"]>[0]
>;
type Factory = NonNullable<Parameters<ExtensionContext["ui"]["setFooter"]>[0]>;

initTheme("dark");

async function harness(footerFirst: boolean) {
    const manager = SessionManager.inMemory();
    manager.appendCustomEntry("openai-fast-mode", { enabled: true });
    const statuses = new Map<string, string>([["other", "Other status"]]);
    const workingMessages: (string | undefined)[] = [];
    const handlers = new Map<string, Handler[]>();
    let factory: Factory | undefined;
    let editorFactory: EditorFactory | undefined;
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
            theme: {
                fg: (color: string, text: string) =>
                    `\x1b[${color === "accent" ? "35" : "90"}m${text}\x1b[0m`,
                getBashModeBorderColor: () => (text: string) =>
                    `\x1b[33m${text}\x1b[0m`,
            },
            getEditorComponent: () => editorFactory,
            setEditorComponent: (value: EditorFactory | undefined) => {
                editorFactory = value;
            },
            setFooter: (value: Factory | undefined) => {
                factory = value;
            },
            setWorkingMessage: (message?: string) => {
                workingMessages.push(message);
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
        ? [uiExtension, controlExtension, openaiExtension]
        : [controlExtension, openaiExtension, uiExtension];
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
        statuses,
        workingMessages,
        footer,
        editorFactory,
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

        h.statuses.delete(FAST_MODE_STATUS);
        const withoutFast = stripVTControlCharacters(h.footer.render(120)[1]!);
        assert.match(withoutFast, /gpt-6\.1-sol • medium$/u);
        assert.doesNotMatch(withoutFast, /\(fast\)|\(circe-responses\)/u);
        h.footer.dispose?.();
        await h.emit("session_shutdown");
    }
});

test("editor keeps accent-colored borders after host color updates and preserves bash mode", async () => {
    const h = await harness(true);
    assert.ok(h.editorFactory);
    const editor = h.editorFactory(
        {
            terminal: { rows: 24 },
            requestRender() {},
        } as Parameters<EditorFactory>[0],
        { borderColor: (text: string) => text } as Parameters<EditorFactory>[1],
        {} as Parameters<EditorFactory>[2],
    );
    // Simulate the host overwriting the color when reasoning effort changes.
    editor.borderColor = (text) => `\x1b[34m${text}\x1b[0m`;
    const lines = editor.render(40);
    assert.ok(lines[0]!.includes("\x1b[35m"));
    assert.ok(!lines[0]!.includes("\x1b[34m"));
    editor.setText(" !pwd");
    assert.ok(editor.render(40)[0]!.includes("\x1b[33m"));
    editor.setText("");
    assert.ok(editor.render(40)[0]!.includes("\x1b[35m"));
    h.footer.dispose?.();
    await h.emit("session_shutdown");
});

test("working message uses a phrase during a turn and resets afterward", async () => {
    const h = await harness(true);
    await h.emit("turn_start");
    assert.equal(h.workingMessages.length, 1);
    assert.ok(h.workingMessages[0]);
    await h.emit("turn_end");
    assert.deepEqual(h.workingMessages, [h.workingMessages[0], undefined]);
    h.footer.dispose?.();
    await h.emit("session_shutdown");
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
