import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
    mkdtemp,
    mkdir,
    readFile,
    realpath,
    rm,
    symlink,
    writeFile,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test, { type TestContext } from "node:test";
import {
    createAgentSession,
    DefaultResourceLoader,
    ModelRuntime,
    SessionManager,
    SettingsManager,
    type ExtensionAPI,
} from "@earendil-works/pi-coding-agent";
import {
    fauxAssistantMessage,
    fauxProvider,
    fauxToolCall,
    InMemoryCredentialStore,
    InMemoryModelsStore,
} from "@earendil-works/pi-ai";

import interceptorExtension, {
    canonicalizePath,
    commandDecision,
    loadPolicies,
    parseBashCommands,
    parsePolicy,
    pathDecision,
} from "./index.ts";

async function tempRoot(t: TestContext): Promise<string> {
    const root = await mkdtemp(path.join(tmpdir(), "pi-interceptor-"));
    t.after(() => rm(root, { recursive: true, force: true }));
    return root;
}

test("runtime dependency versions match development dependencies", async () => {
    const rootPackage = JSON.parse(
        await readFile(new URL("../../package.json", import.meta.url), "utf8"),
    ) as { dependencies: Record<string, string> };
    const runtimePackage = JSON.parse(
        await readFile(
            new URL("../../runtime/package.json", import.meta.url),
            "utf8",
        ),
    ) as { dependencies: Record<string, string> };

    const developmentVersions = Object.fromEntries(
        Object.keys(runtimePackage.dependencies).map((name) => [
            name,
            rootPackage.dependencies[name],
        ]),
    );
    assert.deepEqual(developmentVersions, runtimePackage.dependencies);
});

test("canonicalizePath resolves a symlinked write parent", async (t) => {
    const root = await tempRoot(t);
    const actual = path.join(root, "actual");
    await mkdir(actual);
    await symlink(actual, path.join(root, "link"));
    assert.equal(
        await canonicalizePath("link/new/file", root),
        path.join(await realpath(actual), "new", "file"),
    );
});

test("schema rejects legacy fields, unknown keys, duplicate operations, and unsupported globs", () => {
    for (const policy of [
        { write: { roots: ["$CWD"] } },
        {
            rules: [
                {
                    matches: [{ path: "$CWD", operations: ["read", "read"] }],
                    action: "allow",
                },
            ],
        },
        {
            rules: [
                {
                    matches: [{ path: "src/*.ts", operations: ["read"] }],
                    action: "allow",
                },
            ],
        },
        {
            rules: [
                {
                    matches: [{ path: "$CWD", operations: ["execute"] }],
                    action: "allow",
                },
            ],
        },
        {
            rules: [
                {
                    matches: [{ path: "$CWD", operations: ["read"] }],
                    action: "ask",
                },
            ],
        },
        {
            rules: [
                {
                    matches: [{ path: "$CWD", operations: ["read"] }],
                    action: "ignore",
                },
            ],
        },
        { rules: [{ command: "git *", action: "allow" }] },
        {
            rules: [
                {
                    matches: [{ bash: "git *", operations: ["read"] }],
                    action: "allow",
                },
            ],
        },
        { rules: [{ matches: [{ bash: "" }], action: "allow" }] },
        {
            rules: [
                { matches: [{ bash: "pip *" }], action: "deny", message: "" },
            ],
        },
        {
            rules: [
                { matches: [{ bash: "pip *" }], action: "deny", message: 42 },
            ],
        },
        {
            rules: [
                {
                    matches: [{ bash: "pip *" }],
                    action: "deny",
                    message: "x".repeat(501),
                },
            ],
        },
    ]) {
        assert.throws(() => parsePolicy(policy));
    }
});

async function interceptorLifecycleHarness(
    sessionManager = SessionManager.inMemory(),
) {
    const handlers = new Map<string, (...args: any[]) => any>();
    const notifications: string[] = [];
    const messages: {
        content: string;
        details: { key: string };
        options: unknown;
    }[] = [];
    const pi = {
        on(name: string, handler: (...args: any[]) => any) {
            handlers.set(name, (event: unknown, ctx: any) =>
                handler(event, { sessionManager, ...ctx }),
            );
        },
        sendMessage(message: any, options: unknown) {
            messages.push({ ...message, options });
            sessionManager.appendCustomMessageEntry(
                message.customType,
                message.content,
                message.display,
                message.details,
            );
        },
    } as unknown as ExtensionAPI;
    await interceptorExtension(pi);
    return { pi, handlers, notifications, messages, sessionManager };
}

test("file policy changes take effect only after session start or reload", async (t) => {
    const root = await tempRoot(t);
    const config = path.join(root, "config");
    await mkdir(config);
    const policyFile = path.join(config, "interceptor.json");
    await writeFile(
        policyFile,
        JSON.stringify({
            rules: [{ matches: [{ bash: "*" }], action: "allow" }],
        }),
    );
    const previousConfig = process.env.PI_CODING_AGENT_DIR;
    process.env.PI_CODING_AGENT_DIR = config;
    const harness = await interceptorLifecycleHarness();
    const ctx = {
        cwd: root,
        hasUI: true,
        ui: {
            notify: (message: string) => harness.notifications.push(message),
        },
        isProjectTrusted: () => false,
    };
    try {
        await harness.handlers.get("session_start")!({}, ctx);
        await writeFile(
            policyFile,
            JSON.stringify({
                rules: [{ matches: [{ bash: "*" }], action: "deny" }],
            }),
        );
        assert.equal(
            await harness.handlers.get("tool_call")!(
                { toolName: "bash", input: { command: "npm test" } },
                ctx,
            ),
            undefined,
        );

        await harness.handlers.get("session_start")!({}, ctx);
        const result = (await harness.handlers.get("tool_call")!(
            { toolName: "bash", input: { command: "npm test" } },
            ctx,
        )) as { block: boolean };
        assert.equal(result.block, true);
    } finally {
        if (previousConfig === undefined)
            delete process.env.PI_CODING_AGENT_DIR;
        else process.env.PI_CODING_AGENT_DIR = previousConfig;
    }
});

test("invalid reload warns and retains the matching last valid policy", async (t) => {
    const root = await tempRoot(t);
    const config = path.join(root, "config");
    await mkdir(config);
    const policyFile = path.join(config, "interceptor.json");
    await writeFile(
        policyFile,
        JSON.stringify({
            rules: [{ matches: [{ bash: "*" }], action: "allow" }],
        }),
    );
    const previousConfig = process.env.PI_CODING_AGENT_DIR;
    process.env.PI_CODING_AGENT_DIR = config;
    try {
        const initial = await interceptorLifecycleHarness();
        const initialContext = {
            cwd: root,
            hasUI: true,
            ui: {
                notify: (message: string) =>
                    initial.notifications.push(message),
            },
            isProjectTrusted: () => false,
        };
        await initial.handlers.get("session_start")!({}, initialContext);
        await writeFile(policyFile, "not JSON");

        const reloaded = await interceptorLifecycleHarness();
        const reloadedContext = {
            ...initialContext,
            ui: {
                notify: (message: string) =>
                    reloaded.notifications.push(message),
            },
        };
        await reloaded.handlers.get("session_start")!(
            { reason: "reload" },
            reloadedContext,
        );

        assert.match(
            reloaded.notifications[0] ?? "",
            /using last valid policy\.$/u,
        );
        assert.equal(
            await reloaded.handlers.get("tool_call")!(
                { toolName: "bash", input: { command: "npm test" } },
                reloadedContext,
            ),
            undefined,
        );
    } finally {
        if (previousConfig === undefined)
            delete process.env.PI_CODING_AGENT_DIR;
        else process.env.PI_CODING_AGENT_DIR = previousConfig;
    }
});

test("invalid initial policy warns and falls back to an empty policy", async (t) => {
    const root = await tempRoot(t);
    const config = path.join(root, "config");
    await mkdir(config);
    await writeFile(path.join(config, "interceptor.json"), "not JSON");
    const previousConfig = process.env.PI_CODING_AGENT_DIR;
    process.env.PI_CODING_AGENT_DIR = config;
    const harness = await interceptorLifecycleHarness();
    const ctx = {
        cwd: root,
        hasUI: true,
        ui: {
            notify: (message: string) => harness.notifications.push(message),
        },
        isProjectTrusted: () => false,
    };
    try {
        await harness.handlers.get("session_start")!({}, ctx);
        assert.match(harness.notifications[0] ?? "", /using empty policy\.$/u);
        const result = (await harness.handlers.get("tool_call")!(
            { toolName: "bash", input: { command: "npm test" } },
            ctx,
        )) as { block: boolean };
        assert.equal(result.block, true);
    } finally {
        if (previousConfig === undefined)
            delete process.env.PI_CODING_AGENT_DIR;
        else process.env.PI_CODING_AGENT_DIR = previousConfig;
    }
});

test("Bash rules use wildcards and last match wins", async () => {
    const policy = parsePolicy({
        rules: [
            { matches: [{ bash: "*" }], action: "deny" },
            { matches: [{ bash: "git *" }], action: "allow" },
            { matches: [{ bash: "git push*" }], action: "deny" },
            { matches: [{ bash: "git status --?hort" }], action: "allow" },
        ],
    });
    assert.equal(
        (await commandDecision(policy, "git status --short", process.cwd()))
            .action,
        "allow",
    );
    assert.equal(
        (await commandDecision(policy, "git push origin main", process.cwd()))
            .action,
        "deny",
    );
    assert.equal(
        (await commandDecision(policy, "npm test", process.cwd())).action,
        "deny",
    );
});

test("deny rules return custom reasons without matching prefixed commands", async () => {
    const policy = parsePolicy({
        rules: [
            { matches: [{ bash: "*" }], action: "allow" },
            {
                matches: [{ bash: "pip" }],
                action: "deny",
                message: "Use `uv pip` instead.",
            },
            {
                matches: [{ bash: "pip *" }],
                action: "deny",
                message: "Use `uv pip` instead.",
            },
            {
                matches: [{ bash: "pip3" }],
                action: "deny",
                message: "Use `uv pip` instead.",
            },
            {
                matches: [{ bash: "pip3 *" }],
                action: "deny",
                message: "Use `uv pip` instead.",
            },
        ],
    });
    assert.deepEqual(await commandDecision(policy, "pip", process.cwd()), {
        action: "deny",
        reason: 'Use `uv pip` instead. Matched rule: {"matches":[{"bash":"pip"}],"action":"deny"}',
    });
    assert.deepEqual(
        await commandDecision(policy, "pip install requests", process.cwd()),
        {
            action: "deny",
            reason: 'Use `uv pip` instead. Matched rule: {"matches":[{"bash":"pip *"}],"action":"deny"}',
        },
    );
    assert.deepEqual(
        await commandDecision(policy, "pip3 install requests", process.cwd()),
        {
            action: "deny",
            reason: 'Use `uv pip` instead. Matched rule: {"matches":[{"bash":"pip3 *"}],"action":"deny"}',
        },
    );
    assert.equal(
        (
            await commandDecision(
                policy,
                "uv pip install requests",
                process.cwd(),
            )
        ).action,
        "allow",
    );
});

test("tool blocks identify winning rules while unmatched and invalid inputs keep their reasons", async (t) => {
    const root = await tempRoot(t);
    await mkdir(path.join(root, ".pi"));
    await writeFile(
        path.join(root, ".pi", "interceptor.json"),
        JSON.stringify({
            rules: [
                { matches: [{ bash: "pip *" }], action: "allow" },
                {
                    matches: [{ bash: "pip *" }],
                    action: "deny",
                    message: "Use `uv pip` instead.",
                },
                {
                    matches: [{ path: "secret", operations: ["read"] }],
                    action: "allow",
                },
                {
                    matches: [{ path: "secret", operations: ["read"] }],
                    action: "deny",
                },
            ],
        }),
    );
    const previousConfig = process.env.PI_CODING_AGENT_DIR;
    process.env.PI_CODING_AGENT_DIR = path.join(root, "global");
    try {
        const harness = await interceptorLifecycleHarness();
        const ctx = { cwd: root, hasUI: false, isProjectTrusted: () => true };
        await harness.handlers.get("session_start")!({}, ctx);
        for (const [toolName, input, reason] of [
            [
                "bash",
                { command: "pip install requests" },
                'Use `uv pip` instead. Matched rule: {"matches":[{"bash":"pip *"}],"action":"deny"}',
            ],
            [
                "read",
                { path: "secret" },
                `secret matches ${root}/secret. Matched rule: {"matches":[{"path":"${root}/secret","operations":["read"]}],"action":"deny"}`,
            ],
            [
                "bash",
                { command: "npm test" },
                "npm test does not match a Bash rule",
            ],
            [
                "read",
                { path: "other" },
                "other does not match a permission rule",
            ],
            ["bash", { command: "if then" }, "invalid Bash syntax"],
            ["read", {}, "read did not provide a path argument"],
        ] as const) {
            assert.deepEqual(
                await harness.handlers.get("tool_call")!(
                    { toolName, input },
                    ctx,
                ),
                {
                    block: true,
                    reason: `Interceptor denied the tool call: ${reason}`,
                },
            );
        }
    } finally {
        if (previousConfig === undefined)
            delete process.env.PI_CODING_AGENT_DIR;
        else process.env.PI_CODING_AGENT_DIR = previousConfig;
    }
});

test("every command in a shell chain must be allowed", async () => {
    const policy = parsePolicy({
        rules: [
            { matches: [{ bash: "*" }], action: "deny" },
            { matches: [{ bash: "git *" }], action: "allow" },
            { matches: [{ bash: "rm *" }], action: "deny" },
        ],
    });
    assert.deepEqual(
        await parseBashCommands("git status && git diff | git apply --check"),
        ["git status", "git diff", "git apply --check"],
    );
    assert.equal(
        (await commandDecision(policy, "git status && npm test", process.cwd()))
            .action,
        "deny",
    );
    assert.equal(
        (
            await commandDecision(
                policy,
                "git status; rm -rf build",
                process.cwd(),
            )
        ).action,
        "deny",
    );
    assert.equal(
        (await commandDecision(policy, "git log --format='a;b'", process.cwd()))
            .action,
        "allow",
    );
});

test("complex shell substitutions evaluate nested commands", async () => {
    const policy = parsePolicy({
        rules: [
            { matches: [{ bash: "printf *" }], action: "allow" },
            { matches: [{ bash: "diff *" }], action: "allow" },
        ],
    });
    assert.equal(
        (
            await commandDecision(
                policy,
                "printf '%s' $(cat secret)",
                process.cwd(),
            )
        ).action,
        "deny",
    );
    assert.equal(
        (await commandDecision(policy, 'printf "`cat secret`"', process.cwd()))
            .action,
        "deny",
    );
    assert.equal(
        (
            await commandDecision(
                policy,
                "diff <(first) <(second)",
                process.cwd(),
            )
        ).action,
        "deny",
    );
});

test("Bash parser keeps a heredoc with its redirected command", async () => {
    const heredoc = "node <<'JS'\nconsole.log(process.cwd())\nJS";
    assert.deepEqual(await parseBashCommands(heredoc), [heredoc]);
    assert.equal(await parseBashCommands("if then"), undefined);
});

test("valid Bash forms never report a parser failure", async () => {
    const commands = [
        "NAME=value",
        "# comment only",
        "printf '%s\\n' \"$(pwd)\"",
        "diff <(printf a) <(printf b)",
        "(cd /tmp && pwd)",
        "{ echo one; echo two; }",
        "if test -f file; then echo yes; else echo no; fi",
        'for item in one two; do echo "$item"; done',
        "case $value in one) echo yes ;; *) echo no ;; esac",
        "function greet() { echo hello; }; greet",
        "node <<'JS'\nconsole.log(process.cwd())\nJS",
    ];
    for (const command of commands) {
        assert.notEqual(await parseBashCommands(command), undefined, command);
    }
});

test("valid Bash without an executable command is allowed", async () => {
    const policy = parsePolicy({
        rules: [{ matches: [{ bash: "*" }], action: "deny" }],
    });
    assert.equal(
        (await commandDecision(policy, "NAME=value", process.cwd())).action,
        "allow",
    );
});

test("invalid Bash syntax is denied without interaction", async () => {
    const policy = parsePolicy({
        rules: [{ matches: [{ bash: "git *" }], action: "allow" }],
    });
    assert.deepEqual(await commandDecision(policy, "if then", process.cwd()), {
        action: "deny",
        reason: "invalid Bash syntax",
    });
});

test("a final catch-all allow bypasses parsing complex shell syntax", async () => {
    const policy = parsePolicy({
        rules: [{ matches: [{ bash: "*" }], action: "allow" }],
    });
    const heredoc = "node <<'JS'\nconsole.log(process.cwd())\nJS";
    assert.equal(
        (await commandDecision(policy, heredoc, process.cwd())).action,
        "allow",
    );
});

test("narrower allows after catch-all allow still bypass parsing", async () => {
    const policy = parsePolicy({
        rules: [
            { matches: [{ bash: "*" }], action: "allow" },
            { matches: [{ bash: "git *" }], action: "allow" },
        ],
    });
    assert.equal(
        (
            await commandDecision(
                policy,
                "printf '%s' $(cat secret)",
                process.cwd(),
            )
        ).action,
        "allow",
    );
});

test("a restrictive rule after catch-all allow evaluates nested commands", async () => {
    const policy = parsePolicy({
        rules: [
            { matches: [{ bash: "*" }], action: "allow" },
            { matches: [{ bash: "rm *" }], action: "deny" },
        ],
    });
    assert.equal(
        (
            await commandDecision(
                policy,
                "printf '%s' $(rm secret)",
                process.cwd(),
            )
        ).action,
        "deny",
    );
});

test("last matching path rule wins and no match denies", async (t) => {
    const root = await tempRoot(t);
    const policy = parsePolicy({
        rules: [
            {
                matches: [{ path: "/**", operations: ["read"] }],
                action: "allow",
            },
            {
                matches: [{ path: "$CWD/secret/**", operations: ["read"] }],
                action: "deny",
                message: "Secrets must not be sent to the model provider.",
            },
            {
                matches: [
                    { path: "$CWD/secret/approved", operations: ["read"] },
                ],
                action: "allow",
            },
        ],
    });
    assert.deepEqual(await pathDecision(policy, "read", "secret/key", root), {
        action: "deny",
        reason: `Secrets must not be sent to the model provider. Matched rule: {"matches":[{"path":"${root}/secret/**","operations":["read"]}],"action":"deny"}`,
    });
    assert.equal(
        (await pathDecision(policy, "read", "secret/approved", root)).action,
        "allow",
    );
    assert.equal(
        (await pathDecision(policy, "write", "new-file", root)).action,
        "deny",
    );
});

test("trusted project rules append after global rules", async (t) => {
    const root = await tempRoot(t);
    const global = path.join(root, "global");
    await mkdir(global);
    await mkdir(path.join(root, ".pi"));
    await writeFile(
        path.join(global, "interceptor.json"),
        JSON.stringify({
            rules: [
                {
                    matches: [{ path: "$CWD/**", operations: ["write"] }],
                    action: "deny",
                },
            ],
        }),
    );
    await writeFile(
        path.join(root, ".pi", "interceptor.json"),
        JSON.stringify({
            rules: [
                {
                    matches: [
                        { path: "$CWD/generated/**", operations: ["write"] },
                    ],
                    action: "allow",
                },
            ],
        }),
    );

    const trusted = await loadPolicies({
        cwd: root,
        projectTrusted: true,
        globalConfigDir: global,
    });
    assert.ok("rules" in trusted);
    if ("rules" in trusted)
        assert.equal(
            (await pathDecision(trusted.rules, "write", "generated/file", root))
                .action,
            "allow",
        );

    const untrusted = await loadPolicies({
        cwd: root,
        projectTrusted: false,
        globalConfigDir: global,
    });
    assert.ok("rules" in untrusted);
    if ("rules" in untrusted)
        assert.equal(
            (
                await pathDecision(
                    untrusted.rules,
                    "write",
                    "generated/file",
                    root,
                )
            ).action,
            "deny",
        );
});

test("malformed eligible project policy fails closed", async (t) => {
    const root = await tempRoot(t);
    await mkdir(path.join(root, ".pi"));
    await writeFile(
        path.join(root, ".pi", "interceptor.json"),
        JSON.stringify({ read: { allow: [] } }),
    );
    const globalConfigDir = path.join(root, "missing-global");
    assert.ok(
        "error" in
            (await loadPolicies({
                cwd: root,
                projectTrusted: true,
                globalConfigDir,
            })),
    );
    assert.ok(
        "rules" in
            (await loadPolicies({
                cwd: root,
                projectTrusted: false,
                globalConfigDir,
            })),
    );
});

test("dangling policy symlinks fail closed instead of looking absent", async (t) => {
    const root = await tempRoot(t);
    const global = path.join(root, "global");
    await mkdir(global);
    await symlink(
        path.join(root, "missing-policy.json"),
        path.join(global, "interceptor.json"),
    );
    assert.ok(
        "error" in
            (await loadPolicies({
                cwd: root,
                projectTrusted: false,
                globalConfigDir: global,
            })),
    );
});

test("placeholders and symlinks retain sensitive lexical matching without allowing escapes", async (t) => {
    const root = await tempRoot(t);
    const outside = await tempRoot(t);
    const actual = path.join(root, "actual");
    await mkdir(actual);
    await symlink(outside, path.join(root, "link"));
    await symlink(actual, path.join(root, "alias"));
    const policy = parsePolicy({
        rules: [
            {
                matches: [{ path: "$CWD/**", operations: ["write"] }],
                action: "allow",
            },
            {
                matches: [{ path: "$CWD/link/**", operations: ["read"] }],
                action: "deny",
            },
            {
                matches: [
                    { path: "~/does-not-exist/**", operations: ["read"] },
                ],
                action: "deny",
            },
        ],
    });
    assert.equal(
        (await pathDecision(policy, "write", "link/new-file", root)).action,
        "deny",
    );
    assert.equal(
        (await pathDecision(policy, "read", "link/new-file", root)).action,
        "deny",
    );
    assert.equal(
        (
            await pathDecision(
                policy,
                "read",
                path.join(process.env.HOME!, "does-not-exist", "key"),
                root,
            )
        ).action,
        "deny",
    );
    const canonicalPolicy = parsePolicy({
        rules: [
            {
                matches: [{ path: "$CWD/actual/**", operations: ["write"] }],
                action: "allow",
            },
        ],
    });
    assert.equal(
        (await pathDecision(canonicalPolicy, "write", "alias/new-file", root))
            .action,
        "allow",
    );
});

async function policyHarness(
    t: TestContext,
    rules: unknown[],
    mode: "tui" | "print" = "print",
) {
    const root = await tempRoot(t);
    const previousConfig = process.env.PI_CODING_AGENT_DIR;
    process.env.PI_CODING_AGENT_DIR = root;
    t.after(() => {
        if (previousConfig === undefined)
            delete process.env.PI_CODING_AGENT_DIR;
        else process.env.PI_CODING_AGENT_DIR = previousConfig;
    });
    await writeFile(
        path.join(root, "interceptor.json"),
        JSON.stringify({ rules }),
    );
    const harness = await interceptorLifecycleHarness();
    const ctx = {
        cwd: root,
        mode,
        hasUI: mode === "tui",
        ui: {
            notify: (message: string) => harness.notifications.push(message),
        },
        isProjectTrusted: () => false,
    };
    await harness.handlers.get("session_start")!({ reason: "startup" }, ctx);
    const call = (toolName: string, input: unknown) =>
        harness.handlers.get("tool_call")!({ toolName, input }, ctx);
    return { ...harness, root, ctx, call };
}

const tmpReminder = {
    action: "remind",
    matches: [{ path: "$CWD/**", operations: ["write"] }, { bash: "*/tmp/*" }],
    message: "Keep temporary files small.",
};

test("reminder schema defaults once and rejects invalid and legacy fields", () => {
    assert.deepEqual(parsePolicy({ rules: [tmpReminder] }).rules[0], {
        ...tmpReminder,
        once: true,
    });
    for (const rule of [
        { ...tmpReminder, id: "temporary-files" },
        { ...tmpReminder, message: undefined },
        { ...tmpReminder, once: 1 },
        { ...tmpReminder, matches: [] },
        { ...tmpReminder, action: "allow" },
        { ...tmpReminder, action: "deny", once: true },
        { matches: [{ bash: "*", path: "/tmp" }], action: "allow" },
    ])
        assert.throws(() => parsePolicy({ rules: [rule] }));
});

test("mixed OR matchers preserve permission ordering and reminders cannot authorize", async (t) => {
    const root = await tempRoot(t);
    const policy = parsePolicy({
        rules: [
            {
                matches: [
                    { path: "$CWD/**", operations: ["read"] },
                    { bash: "git *" },
                ],
                action: "allow",
            },
            {
                matches: [
                    { path: "$CWD/secret", operations: ["read"] },
                    { bash: "git push*" },
                ],
                action: "deny",
            },
            tmpReminder,
        ],
    });
    assert.equal(
        (await pathDecision(policy, "read", "file", root)).action,
        "allow",
    );
    assert.equal(
        (await pathDecision(policy, "read", "secret", root)).action,
        "deny",
    );
    assert.equal(
        (await pathDecision(policy, "write", "new", root)).action,
        "deny",
    );
    assert.equal(
        (await commandDecision(policy, "git status", root)).action,
        "allow",
    );
    assert.equal(
        (await commandDecision(policy, "git status && git push", root)).action,
        "deny",
    );
    assert.equal(
        (await commandDecision(policy, "echo /tmp/new", root)).action,
        "deny",
    );
});

test("allowed file and Bash calls share one non-blocking model-visible reminder and TUI notice", async (t) => {
    const h = await policyHarness(
        t,
        [
            {
                matches: [
                    { path: "$CWD/**", operations: ["write"] },
                    { bash: "*" },
                ],
                action: "allow",
            },
            tmpReminder,
        ],
        "tui",
    );
    assert.equal(
        await h.call("write", { path: path.join(h.root, "new") }),
        undefined,
    );
    assert.equal(h.messages.length, 1);
    assert.equal(await h.call("bash", { command: "echo /tmp/new" }), undefined);
    assert.equal(
        await h.call("edit", { path: path.join(h.root, "new") }),
        undefined,
    );
    assert.equal(h.messages.length, 1);
    assert.equal(h.messages[0].content, tmpReminder.message);
    assert.deepEqual(h.messages[0].options, { triggerTurn: false });
    assert.deepEqual(h.notifications, [`Interceptor: ${tmpReminder.message}`]);
    const context = h.sessionManager.buildSessionContext();
    assert.ok(
        context.messages.some(
            (message) =>
                message.role === "custom" &&
                message.content === tmpReminder.message,
        ),
    );
});

test("once false emits on every matching allowed call but never on denied calls", async (t) => {
    const h = await policyHarness(
        t,
        [
            { matches: [{ bash: "*" }], action: "allow" },
            { ...tmpReminder, once: false },
            {
                ...tmpReminder,
                message: "Clean up\n\u001b[1mafterward\u001b[0m.",
                once: false,
            },
            { matches: [{ bash: "rm *" }], action: "deny" },
        ],
        "tui",
    );
    assert.equal(await h.call("bash", { command: "echo /tmp/a" }), undefined);
    assert.equal(await h.call("bash", { command: "echo /tmp/b" }), undefined);
    assert.equal((await h.call("bash", { command: "rm /tmp/c" })).block, true);
    assert.equal(h.messages.length, 4);
    const notice = `Interceptor: ${tmpReminder.message}\nInterceptor: Clean up afterward.`;
    assert.deepEqual(h.notifications, [notice, notice]);
});

test("concurrent matches emit once and successful compaction re-arms persisted suppression", async (t) => {
    const h = await policyHarness(t, [
        { matches: [{ bash: "*" }], action: "allow" },
        tmpReminder,
    ]);
    await Promise.all([
        h.call("bash", { command: "echo /tmp/a" }),
        h.call("bash", { command: "echo /tmp/b" }),
    ]);
    assert.equal(h.messages.length, 1);
    // A new extension instance models /reload or resuming the same session.
    const reloaded = await interceptorLifecycleHarness(h.sessionManager);
    await reloaded.handlers.get("session_start")!({ reason: "reload" }, h.ctx);
    const call = () =>
        reloaded.handlers.get("tool_call")!(
            { toolName: "bash", input: { command: "echo /tmp/c" } },
            h.ctx,
        );
    await call();
    assert.equal(reloaded.messages.length, 0);
    h.sessionManager.appendCompaction("summary", null, 1000);
    await reloaded.handlers.get("session_compact")!({}, h.ctx);
    assert.equal(reloaded.messages.length, 0);
    await call();
    await call();
    assert.equal(reloaded.messages.length, 1);
    const resumed = await interceptorLifecycleHarness(h.sessionManager);
    await resumed.handlers.get("session_start")!({ reason: "resume" }, h.ctx);
    await resumed.handlers.get("tool_call")!(
        { toolName: "bash", input: { command: "echo /tmp/d" } },
        h.ctx,
    );
    assert.equal(resumed.messages.length, 0);
    const fresh = await interceptorLifecycleHarness();
    await fresh.handlers.get("session_start")!({ reason: "new" }, h.ctx);
    await fresh.handlers.get("tool_call")!(
        { toolName: "bash", input: { command: "echo /tmp/e" } },
        h.ctx,
    );
    assert.equal(fresh.messages.length, 1);
});

test("reminder history survives reordering and distinguishes matcher and message changes", async (t) => {
    const allow = { matches: [{ bash: "*" }], action: "allow" };
    const h = await policyHarness(t, [allow, tmpReminder, tmpReminder]);
    const command = "echo /tmp/file";
    assert.equal(await h.call("bash", { command }), undefined);
    assert.equal(h.messages.length, 1);

    const changedMatches = {
        ...tmpReminder,
        matches: tmpReminder.matches.map((matcher) =>
            "path" in matcher ? { ...matcher, path: `${h.root}/**` } : matcher,
        ),
    };
    const changedMessage = { ...tmpReminder, message: "Clean up afterward." };
    await writeFile(
        path.join(h.root, "interceptor.json"),
        JSON.stringify({
            rules: [tmpReminder, allow, changedMatches, changedMessage],
        }),
    );
    const reloaded = await interceptorLifecycleHarness(h.sessionManager);
    await reloaded.handlers.get("session_start")!({ reason: "reload" }, h.ctx);
    assert.equal(
        await reloaded.handlers.get("tool_call")!(
            { toolName: "bash", input: { command } },
            h.ctx,
        ),
        undefined,
    );
    assert.deepEqual(
        reloaded.messages.map((message) => message.content),
        [changedMatches.message, changedMessage.message],
    );
});

test("environment paths are snapshotted on load while Bash patterns and messages stay literal", async (t) => {
    const name = "PI_INTERCEPTOR_TEST_ROOT";
    const previous = process.env[name];
    t.after(() => {
        if (previous === undefined) delete process.env[name];
        else process.env[name] = previous;
    });
    const root = await tempRoot(t);
    process.env[name] = root;
    const variable = "$" + "{" + name + "}";
    const h = await policyHarness(t, [
        {
            matches: [
                { path: variable + "/**", operations: ["write"] },
                { bash: "echo " + variable },
            ],
            action: "allow",
        },
        {
            ...tmpReminder,
            matches: [{ path: variable + "/**", operations: ["write"] }],
            message: variable,
        },
        {
            matches: [{ path: "$CWD/**", operations: ["read"] }],
            action: "allow",
        },
        {
            matches: [
                { path: variable + "/**", operations: ["read"] },
                { path: "$CWD/secret", operations: ["read"] },
            ],
            action: "deny",
        },
    ]);
    process.env[name] = "/not-the-loaded-root";
    assert.equal(
        await h.call("write", { path: path.join(root, "file") }),
        undefined,
    );
    assert.equal(h.messages[0].content, variable);
    assert.equal(
        await h.call("bash", { command: "echo " + variable }),
        undefined,
    );
    assert.equal(
        (await h.call("bash", { command: "echo " + root })).block,
        true,
    );
    process.env[name] = "$CWD";
    const literal = await loadPolicies({ cwd: h.root, projectTrusted: false });
    assert.ok("rules" in literal);
    assert.equal(
        (await pathDecision(literal.rules, "write", "$CWD/file", h.root))
            .action,
        "allow",
    );
    for (const value of [undefined, ""]) {
        if (value === undefined) delete process.env[name];
        else process.env[name] = value;
        const loaded = await loadPolicies({
            cwd: h.root,
            projectTrusted: false,
        });
        assert.ok("rules" in loaded);
        assert.deepEqual(loaded.rules[0].matches, [
            { bash: "echo " + variable },
        ]);
        assert.deepEqual(loaded.rules[1].matches, []);

        await h.handlers.get("session_start")!({ reason: "reload" }, h.ctx);
        assert.equal(
            await h.call("bash", { command: "echo " + variable }),
            undefined,
        );
        assert.equal(
            (await h.call("write", { path: path.join(root, "file") })).block,
            true,
        );
        assert.equal(await h.call("read", { path: "file" }), undefined);
        assert.equal((await h.call("read", { path: "secret" })).block, true);
    }
    for (const value of ["/tmp/*", "$" + "{OTHER}"]) {
        process.env[name] = value;
        const loaded = await loadPolicies({
            cwd: h.root,
            projectTrusted: false,
        });
        assert.ok("error" in loaded);
    }
});

test("identical reminders in global and trusted-project files deliver independently", async (t) => {
    const h = await policyHarness(t, [
        { matches: [{ bash: "*" }], action: "allow" },
        tmpReminder,
    ]);
    await mkdir(path.join(h.root, ".pi"));
    await writeFile(
        path.join(h.root, ".pi", "interceptor.json"),
        JSON.stringify({ rules: [tmpReminder] }),
    );
    const ctx = { ...h.ctx, isProjectTrusted: () => true };
    await h.handlers.get("session_start")!({ reason: "reload" }, ctx);
    await h.handlers.get("tool_call")!(
        { toolName: "bash", input: { command: "echo /tmp/a" } },
        ctx,
    );
    assert.equal(h.messages.length, 2);
    assert.notEqual(h.messages[0].details.key, h.messages[1].details.key);
});

test("invalid schema warns before startup completes and factory reloads do not write over the TUI", async (t) => {
    const root = await tempRoot(t);
    await writeFile(
        path.join(root, "interceptor.json"),
        JSON.stringify({ rules: [{ action: "allow", matches: [] }] }),
    );
    const module = new URL("./index.ts", import.meta.url).href;
    const result = spawnSync(
        process.execPath,
        [
            "--import",
            "tsx",
            "--input-type=module",
            "-e",
            "import interceptor from " +
                JSON.stringify(module) +
                ";" +
                "await interceptor({on(){}}); process.stderr.write('startup-complete\\n');" +
                "await interceptor({on(){}}); process.stderr.write('reload-complete\\n');",
        ],
        {
            // Resolve tsx from the package while keeping policy lookup independent.
            cwd: path.resolve(import.meta.dirname, "../.."),
            env: { ...process.env, PI_CODING_AGENT_DIR: root },
            encoding: "utf8",
        },
    );
    assert.equal(result.status, 0, result.stderr);
    assert.match(
        result.stderr,
        /^Interceptor configuration warning:.*matches must be a non-empty array.*\nstartup-complete\nreload-complete\n$/,
    );
});

test("real tool execution delivers reminders on the next request without skipping sibling calls", async (t) => {
    const h = await policyHarness(t, [
        { matches: [{ bash: "*" }], action: "allow" },
        { ...tmpReminder, matches: [{ bash: "*" }] },
    ]);
    const faux = fauxProvider({
        models: [
            { id: "interceptor-test", contextWindow: 32000, maxTokens: 1024 },
        ],
    });
    const modelRuntime = await ModelRuntime.create({
        modelsPath: null,
        refreshOnCreate: false,
        credentials: new InMemoryCredentialStore(),
        modelsStore: new InMemoryModelsStore(),
    });
    modelRuntime.registerNativeProvider(faux.provider);
    await modelRuntime.setRuntimeApiKey(faux.getModel().provider, "test-only");
    const settings = SettingsManager.create(h.root, h.root, {
        projectTrusted: false,
    });
    const loader = new DefaultResourceLoader({
        cwd: h.root,
        agentDir: h.root,
        settingsManager: settings,
        noExtensions: true,
        noSkills: true,
        noPromptTemplates: true,
        noThemes: true,
        agentsFilesOverride: () => ({ agentsFiles: [] }),
        extensionFactories: [interceptorExtension],
    });
    await loader.reload();
    const { session } = await createAgentSession({
        cwd: h.root,
        agentDir: h.root,
        modelRuntime,
        model: faux.getModel(),
        sessionManager: SessionManager.inMemory(h.root),
        settingsManager: settings,
        resourceLoader: loader,
        tools: ["bash"],
    });
    t.after(() => session.dispose());
    const errors: string[] = [];
    await session.bindExtensions({
        onError: (error) => errors.push(error.error),
    });
    let nextRequest = "";
    let outputs: string[] = [];
    faux.setResponses([
        fauxAssistantMessage(
            [
                fauxToolCall(
                    "bash",
                    { command: "printf first" },
                    { id: "first" },
                ),
                fauxToolCall(
                    "bash",
                    { command: "printf second" },
                    { id: "second" },
                ),
            ],
            { stopReason: "toolUse" },
        ),
        (context) => {
            nextRequest = JSON.stringify(context.messages);
            outputs = context.messages
                .filter((message) => message.role === "toolResult")
                .map((message) =>
                    message.content
                        .filter((part) => part.type === "text")
                        .map((part) => part.text)
                        .join(""),
                );
            return fauxAssistantMessage("Done.");
        },
    ]);
    await session.prompt("Execute both commands.");
    assert.deepEqual(outputs, ["first", "second"]);
    assert.equal(nextRequest.split(tmpReminder.message).length - 1, 1);
    assert.doesNotMatch(nextRequest, /skipped|aborted/i);
    assert.equal(faux.state.callCount, 2);
    assert.deepEqual(errors, []);
});

test("reminder delivery failure neither blocks execution nor consumes once", async (t) => {
    const h = await policyHarness(
        t,
        [{ matches: [{ bash: "*" }], action: "allow" }, tmpReminder],
        "tui",
    );
    const warnings: string[] = [];
    const stderr = t.mock.method(process.stderr, "write", (value: string) => {
        warnings.push(value);
        return true;
    });
    const send = t.mock.method(h.pi, "sendMessage", () => {
        throw new Error("delivery unavailable");
    });
    assert.equal(await h.call("bash", { command: "echo /tmp/a" }), undefined);
    assert.equal(h.messages.length, 0);
    assert.deepEqual(h.notifications, []);
    assert.match(warnings[0], /delivery unavailable/);
    send.mock.restore();
    stderr.mock.restore();
    assert.equal(await h.call("bash", { command: "echo /tmp/b" }), undefined);
    assert.equal(h.messages.length, 1);
});
