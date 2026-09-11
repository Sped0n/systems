import assert from "node:assert/strict";
import {
  mkdtemp,
  mkdir,
  readFile,
  realpath,
  symlink,
  writeFile,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

import interceptorExtension, {
  appendInterceptorRules,
  canonicalizePath,
  commandDecision,
  GIT_INSPECTION_BASH_POLICY,
  loadPolicies,
  parseBashCommands,
  parsePolicy,
  pathDecision,
} from "./index.ts";

async function tempRoot(): Promise<string> {
  return mkdtemp(path.join(tmpdir(), "pi-permissions-"));
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

test("canonicalizePath resolves a symlinked write parent", async () => {
  const root = await tempRoot();
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
      rules: [{ path: "$CWD", operations: ["read", "read"], action: "allow" }],
    },
    { rules: [{ path: "src/*.ts", operations: ["read"], action: "allow" }] },
    { rules: [{ path: "$CWD", operations: ["execute"], action: "allow" }] },
    { rules: [{ path: "$CWD", operations: ["read"], action: "ask" }] },
    { rules: [{ path: "$CWD", operations: ["read"], action: "ignore" }] },
    { rules: [{ command: "git *", action: "allow" }] },
    { rules: [{ bash: "git *", operations: ["read"], action: "allow" }] },
    { rules: [{ bash: "", action: "allow" }] },
    { rules: [{ bash: "pip *", action: "deny", reason: "" }] },
    { rules: [{ bash: "pip *", action: "deny", reason: 42 }] },
    { rules: [{ bash: "pip *", action: "deny", reason: "x".repeat(501) }] },
  ]) {
    assert.throws(() => parsePolicy(policy));
  }
});

function interceptorLifecycleHarness() {
  const handlers = new Map<string, (...args: any[]) => any>();
  const notifications: string[] = [];
  const pi = {
    on(name: string, handler: (...args: any[]) => any) {
      handlers.set(name, handler);
    },
  } as unknown as ExtensionAPI;
  interceptorExtension(pi);
  return { handlers, notifications };
}

test("runtime rules append after file policy and dispose independently", async () => {
  const handlers = new Map<string, (...args: unknown[]) => unknown>();
  const pi = {
    on(name: string, handler: (...args: unknown[]) => unknown) {
      handlers.set(name, handler);
    },
  } as unknown as ExtensionAPI;
  interceptorExtension(pi);
  const sessionStart = handlers.get("session_start");
  const toolCall = handlers.get("tool_call");
  assert.ok(sessionStart);
  assert.ok(toolCall);

  const root = await tempRoot();
  const config = path.join(root, "config");
  await mkdir(config);
  await writeFile(
    path.join(config, "interceptor.json"),
    JSON.stringify({ rules: [{ bash: "*", action: "allow" }] }),
  );
  const previousConfig = process.env.PI_CODING_AGENT_DIR;
  process.env.PI_CODING_AGENT_DIR = config;
  const release = appendInterceptorRules(
    {
      rules: [
        { bash: "*", action: "deny" },
        { bash: "git status*", action: "allow" },
      ],
    },
    root,
  );
  const notifications: string[] = [];
  const ctx = {
    cwd: root,
    hasUI: true,
    ui: { notify: (message: string) => notifications.push(message) },
    isProjectTrusted: () => false,
  };
  try {
    await sessionStart({}, ctx);
    assert.equal(
      await toolCall(
        { toolName: "bash", input: { command: "git status" } },
        ctx,
      ),
      undefined,
    );
    assert.equal(
      (
        (await toolCall(
          { toolName: "bash", input: { command: "npm test" } },
          ctx,
        )) as {
          block: boolean;
        }
      ).block,
      true,
    );
    release();
    release();
    assert.equal(
      await toolCall({ toolName: "bash", input: { command: "npm test" } }, ctx),
      undefined,
    );
  } finally {
    release();
    if (previousConfig === undefined) delete process.env.PI_CODING_AGENT_DIR;
    else process.env.PI_CODING_AGENT_DIR = previousConfig;
  }
});

test("file policy changes take effect only after session start or reload", async () => {
  const root = await tempRoot();
  const config = path.join(root, "config");
  await mkdir(config);
  const policyFile = path.join(config, "interceptor.json");
  await writeFile(
    policyFile,
    JSON.stringify({ rules: [{ bash: "*", action: "allow" }] }),
  );
  const previousConfig = process.env.PI_CODING_AGENT_DIR;
  process.env.PI_CODING_AGENT_DIR = config;
  const harness = interceptorLifecycleHarness();
  const ctx = {
    cwd: root,
    hasUI: true,
    ui: { notify: (message: string) => harness.notifications.push(message) },
    isProjectTrusted: () => false,
  };
  try {
    await harness.handlers.get("session_start")!({}, ctx);
    await writeFile(
      policyFile,
      JSON.stringify({ rules: [{ bash: "*", action: "deny" }] }),
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
    if (previousConfig === undefined) delete process.env.PI_CODING_AGENT_DIR;
    else process.env.PI_CODING_AGENT_DIR = previousConfig;
  }
});

test("invalid reload warns and retains the matching last valid policy", async () => {
  const root = await tempRoot();
  const config = path.join(root, "config");
  await mkdir(config);
  const policyFile = path.join(config, "interceptor.json");
  await writeFile(
    policyFile,
    JSON.stringify({ rules: [{ bash: "*", action: "allow" }] }),
  );
  const previousConfig = process.env.PI_CODING_AGENT_DIR;
  process.env.PI_CODING_AGENT_DIR = config;
  try {
    const initial = interceptorLifecycleHarness();
    const initialContext = {
      cwd: root,
      hasUI: true,
      ui: { notify: (message: string) => initial.notifications.push(message) },
      isProjectTrusted: () => false,
    };
    await initial.handlers.get("session_start")!({}, initialContext);
    await writeFile(policyFile, "not JSON");

    const reloaded = interceptorLifecycleHarness();
    const reloadedContext = {
      ...initialContext,
      ui: { notify: (message: string) => reloaded.notifications.push(message) },
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
    if (previousConfig === undefined) delete process.env.PI_CODING_AGENT_DIR;
    else process.env.PI_CODING_AGENT_DIR = previousConfig;
  }
});

test("invalid initial policy warns and falls back to an empty policy", async () => {
  const root = await tempRoot();
  const config = path.join(root, "config");
  await mkdir(config);
  await writeFile(path.join(config, "interceptor.json"), "not JSON");
  const previousConfig = process.env.PI_CODING_AGENT_DIR;
  process.env.PI_CODING_AGENT_DIR = config;
  const harness = interceptorLifecycleHarness();
  const ctx = {
    cwd: root,
    hasUI: true,
    ui: { notify: (message: string) => harness.notifications.push(message) },
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
    if (previousConfig === undefined) delete process.env.PI_CODING_AGENT_DIR;
    else process.env.PI_CODING_AGENT_DIR = previousConfig;
  }
});

test("Git inspection policy allows Git and rg reads but denies hazardous forms", async () => {
  for (const bash of [
    "git status --short",
    "git diff --cached --no-ext-diff --no-textconv",
    "git log --oneline -10",
    "git show HEAD:src/main.ts",
    "rg --no-config -n pattern src",
    "git show HEAD | rg --no-config pattern",
  ]) {
    assert.equal(
      (await commandDecision(GIT_INSPECTION_BASH_POLICY, bash, process.cwd()))
        .action,
      "allow",
      bash,
    );
  }
  for (const bash of [
    "grep pattern src/main.ts",
    "rg pattern src",
    "rg --no-config --pre processor pattern",
    "git diff --ext-diff",
    "git show --textconv HEAD:file",
    "git log --output=/tmp/log",
    "git status > /tmp/status",
    "npm test",
  ]) {
    assert.equal(
      (await commandDecision(GIT_INSPECTION_BASH_POLICY, bash, process.cwd()))
        .action,
      "deny",
      bash,
    );
  }
});
test("Bash rules use wildcards and last match wins", async () => {
  const policy = parsePolicy({
    rules: [
      { bash: "*", action: "deny" },
      { bash: "git *", action: "allow" },
      { bash: "git push*", action: "deny" },
      { bash: "git status --?hort", action: "allow" },
    ],
  });
  assert.equal(
    (await commandDecision(policy, "git status --short", process.cwd())).action,
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
      { bash: "*", action: "allow" },
      { bash: "pip", action: "deny", reason: "Use `uv pip` instead." },
      { bash: "pip *", action: "deny", reason: "Use `uv pip` instead." },
      { bash: "pip3", action: "deny", reason: "Use `uv pip` instead." },
      { bash: "pip3 *", action: "deny", reason: "Use `uv pip` instead." },
    ],
  });
  assert.deepEqual(await commandDecision(policy, "pip", process.cwd()), {
    action: "deny",
    reason: "Use `uv pip` instead.",
  });
  assert.deepEqual(
    await commandDecision(policy, "pip install requests", process.cwd()),
    {
      action: "deny",
      reason: "Use `uv pip` instead.",
    },
  );
  assert.deepEqual(
    await commandDecision(policy, "pip3 install requests", process.cwd()),
    {
      action: "deny",
      reason: "Use `uv pip` instead.",
    },
  );
  assert.equal(
    (await commandDecision(policy, "uv pip install requests", process.cwd()))
      .action,
    "allow",
  );
});

test("every command in a shell chain must be allowed", async () => {
  const policy = parsePolicy({
    rules: [
      { bash: "*", action: "deny" },
      { bash: "git *", action: "allow" },
      { bash: "rm *", action: "deny" },
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
    (await commandDecision(policy, "git status; rm -rf build", process.cwd()))
      .action,
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
      { bash: "printf *", action: "allow" },
      { bash: "diff *", action: "allow" },
    ],
  });
  assert.equal(
    (await commandDecision(policy, "printf '%s' $(cat secret)", process.cwd()))
      .action,
    "deny",
  );
  assert.equal(
    (await commandDecision(policy, 'printf "`cat secret`"', process.cwd()))
      .action,
    "deny",
  );
  assert.equal(
    (await commandDecision(policy, "diff <(first) <(second)", process.cwd()))
      .action,
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
  const policy = parsePolicy({ rules: [{ bash: "*", action: "deny" }] });
  assert.equal(
    (await commandDecision(policy, "NAME=value", process.cwd())).action,
    "allow",
  );
});

test("invalid Bash syntax is denied without interaction", async () => {
  const policy = parsePolicy({ rules: [{ bash: "git *", action: "allow" }] });
  assert.deepEqual(await commandDecision(policy, "if then", process.cwd()), {
    action: "deny",
    reason: "invalid Bash syntax",
  });
});

test("a final catch-all allow bypasses parsing complex shell syntax", async () => {
  const policy = parsePolicy({ rules: [{ bash: "*", action: "allow" }] });
  const heredoc = "node <<'JS'\nconsole.log(process.cwd())\nJS";
  assert.equal(
    (await commandDecision(policy, heredoc, process.cwd())).action,
    "allow",
  );
});

test("narrower allows after catch-all allow still bypass parsing", async () => {
  const policy = parsePolicy({
    rules: [
      { bash: "*", action: "allow" },
      { bash: "git *", action: "allow" },
    ],
  });
  assert.equal(
    (await commandDecision(policy, "printf '%s' $(cat secret)", process.cwd()))
      .action,
    "allow",
  );
});

test("a restrictive rule after catch-all allow evaluates nested commands", async () => {
  const policy = parsePolicy({
    rules: [
      { bash: "*", action: "allow" },
      { bash: "rm *", action: "deny" },
    ],
  });
  assert.equal(
    (await commandDecision(policy, "printf '%s' $(rm secret)", process.cwd()))
      .action,
    "deny",
  );
});

test("last matching path rule wins and no match denies", async () => {
  const root = await tempRoot();
  const policy = parsePolicy({
    rules: [
      { path: "/**", operations: ["read"], action: "allow" },
      {
        path: "$CWD/secret/**",
        operations: ["read"],
        action: "deny",
        reason: "Secrets must not be sent to the model provider.",
      },
      { path: "$CWD/secret/approved", operations: ["read"], action: "allow" },
    ],
  });
  assert.deepEqual(await pathDecision(policy, "read", "secret/key", root), {
    action: "deny",
    reason: "Secrets must not be sent to the model provider.",
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

test("trusted project rules append after global rules", async () => {
  const root = await tempRoot();
  const global = path.join(root, "global");
  await mkdir(global);
  await mkdir(path.join(root, ".pi"));
  await writeFile(
    path.join(global, "interceptor.json"),
    JSON.stringify({
      rules: [{ path: "$CWD/**", operations: ["write"], action: "deny" }],
    }),
  );
  await writeFile(
    path.join(root, ".pi", "interceptor.json"),
    JSON.stringify({
      rules: [
        { path: "$CWD/generated/**", operations: ["write"], action: "allow" },
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
      (await pathDecision(untrusted.rules, "write", "generated/file", root))
        .action,
      "deny",
    );
});

test("malformed eligible project policy fails closed", async () => {
  const root = await tempRoot();
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

test("dangling policy symlinks fail closed instead of looking absent", async () => {
  const root = await tempRoot();
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

test("placeholders and symlinks retain sensitive lexical matching without allowing escapes", async () => {
  const root = await tempRoot();
  const outside = await tempRoot();
  const actual = path.join(root, "actual");
  await mkdir(actual);
  await symlink(outside, path.join(root, "link"));
  await symlink(actual, path.join(root, "alias"));
  const policy = parsePolicy({
    rules: [
      { path: "$CWD/**", operations: ["write"], action: "allow" },
      { path: "$CWD/link/**", operations: ["read"], action: "deny" },
      { path: "~/does-not-exist/**", operations: ["read"], action: "deny" },
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
    rules: [{ path: "$CWD/actual/**", operations: ["write"], action: "allow" }],
  });
  assert.equal(
    (await pathDecision(canonicalPolicy, "write", "alias/new-file", root))
      .action,
    "allow",
  );
});
