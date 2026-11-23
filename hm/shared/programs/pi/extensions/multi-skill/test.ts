import assert from "node:assert/strict";
import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import {
    fauxAssistantMessage,
    fauxProvider,
    InMemoryCredentialStore,
    InMemoryModelsStore,
} from "@earendil-works/pi-ai";
import {
    createAgentSession,
    DefaultResourceLoader,
    ModelRuntime,
    SessionManager,
    SettingsManager,
    type ExtensionUIContext,
} from "@earendil-works/pi-coding-agent";
import {
    CombinedAutocompleteProvider,
    type AutocompleteProvider,
} from "@earendil-works/pi-tui";

import multiSkill from "./index.ts";

test("complete and send multiple skills in one Pi turn", async (t) => {
    const cwd = await mkdtemp(join(tmpdir(), "pi-multi-skill-"));
    t.after(() => rm(cwd, { recursive: true, force: true }));
    const skills = join(cwd, "skills");
    for (const name of ["first", "second"]) {
        const dir = join(skills, name);
        await mkdir(dir, { recursive: true });
        await writeFile(
            join(dir, "SKILL.md"),
            `---\nname: ${name}\ndescription: Test skill\n---\nInstructions for ${name}.\n`,
        );
    }
    const settingsManager = SettingsManager.create(cwd, cwd, {
        projectTrusted: false,
    });
    const resourceLoader = new DefaultResourceLoader({
        cwd,
        agentDir: cwd,
        settingsManager,
        noExtensions: true,
        extensionFactories: [multiSkill],
    });
    await resourceLoader.reload();
    const faux = fauxProvider();
    const modelRuntime = await ModelRuntime.create({
        modelsPath: null,
        refreshOnCreate: false,
        credentials: new InMemoryCredentialStore(),
        modelsStore: new InMemoryModelsStore(),
    });
    modelRuntime.registerNativeProvider(faux.provider);
    await modelRuntime.setRuntimeApiKey(faux.getModel().provider, "test-only");
    const { session } = await createAgentSession({
        cwd,
        agentDir: cwd,
        settingsManager,
        resourceLoader,
        modelRuntime,
        model: faux.getModel(),
        sessionManager: SessionManager.inMemory(cwd),
    });
    t.after(() => session.dispose());
    let provider: AutocompleteProvider = new CombinedAutocompleteProvider(
        [{ name: "skill:first" }],
        cwd,
    );
    let draft = "";
    const notifications: string[] = [];
    await session.bindExtensions({
        uiContext: {
            addAutocompleteProvider: (wrap) => {
                provider = wrap(provider);
            },
            notify: (message, level) => {
                if (level === "error") notifications.push(message);
            },
            getEditorText: () => draft,
            setEditorText: (text) => {
                draft = text;
            },
        } as ExtensionUIContext,
        onError: (error) => assert.fail(error.error),
    });

    const options = { signal: new AbortController().signal };
    const nextSkill = "/skill:first /skill:";
    const remaining = await provider.getSuggestions(
        [nextSkill],
        0,
        nextSkill.length,
        options,
    );
    assert.deepEqual(
        remaining?.items.map(({ label }) => label),
        ["/skill:second"],
    );
    const allSelected = await provider.getSuggestions(
        [nextSkill + " /skill:second"],
        0,
        nextSkill.length,
        options,
    );
    assert.deepEqual(allSelected?.items ?? [], []);

    const prefix = "/skill:first /skill:se";
    const lines = [prefix + "c Please review."];
    const suggestions = await provider.getSuggestions(
        lines,
        0,
        prefix.length,
        options,
    );
    assert.ok(suggestions?.items[0]);
    const completion = provider.applyCompletion(
        lines,
        0,
        prefix.length,
        suggestions.items[0],
        suggestions.prefix,
    );
    assert.deepEqual(completion.lines, [
        "/skill:first /skill:second Please review.",
    ]);

    let userMessage = "";
    faux.setResponses([
        (context) => {
            const user = context.messages.find(
                (message) => message.role === "user",
            );
            const content = user?.content;
            userMessage =
                typeof content === "string"
                    ? content
                    : (content ?? [])
                          .flatMap((part) =>
                              part.type === "text" ? [part.text] : [],
                          )
                          .join("\n");
            return fauxAssistantMessage("Done.");
        },
    ]);
    await session.prompt(
        "/skill:first /skill:second /skill:first Please review.",
    );
    assert.equal(faux.state.callCount, 1);
    assert.deepEqual(
        userMessage.match(
            /Instructions for (?:first|second)\.|Please review\./g,
        ),
        [
            "Instructions for first.",
            "Instructions for second.",
            "Please review.",
        ],
    );

    const invalid = "/skill:first /skill:missing Please review.";
    await session.prompt(invalid);
    assert.equal(faux.state.callCount, 1);
    assert.equal(draft, invalid);
    assert.match(notifications.join("\n"), /\bmissing\b/);
});
