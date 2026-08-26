import { existsSync, promises as fs } from "node:fs";
import { homedir } from "node:os";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import type { Parser as TreeSitterParser } from "web-tree-sitter";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export { GIT_INSPECTION_BASH_POLICY } from "./policies.ts";

export type Operation = "read" | "write";
export type PermissionAction = "allow" | "deny";
export type PathPermissionRule = {
  path: string;
  operations: Operation[];
  action: PermissionAction;
  reason?: string;
};
export type BashPermissionRule = {
  bash: string;
  action: PermissionAction;
  reason?: string;
};
export type PermissionRule = PathPermissionRule | BashPermissionRule;
export type PermissionPolicy = { rules: PermissionRule[] };
export type ScopedPermissionRule = PermissionRule & { scope: string };
export type PolicyLoad = { rules: ScopedPermissionRule[] } | { error: string };
type ToolName = "read" | "edit" | "write";

const DIRECT_FILE_TOOLS: Record<string, ToolName> = {
  read: "read",
  edit: "edit",
  write: "write",
};
const OPERATIONS: Operation[] = ["read", "write"];
const ACTIONS: PermissionAction[] = ["allow", "deny"];
const REASON_CHARACTERS_MAX = 500;
const FILE_POLICY_CACHE_ENTRIES_MAX = 32;
const FILE_POLICY_CACHE_SYMBOL = Symbol.for("pi.interceptor.last-valid-file-policies");

const runtimeRuleGroups = new Map<symbol, ScopedPermissionRule[]>();

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isNodeError(error: unknown, code: string): boolean {
  return isObject(error) && error.code === code;
}

function onlyKeys(
  value: unknown,
  name: string,
  keys: string[],
): Record<string, unknown> {
  if (!isObject(value)) throw new Error(`${name} must be an object`);
  if (Object.keys(value).some((key) => !keys.includes(key)))
    throw new Error(`${name} has an unknown key`);
  return value;
}

function validateRulePath(value: unknown, name: string): string {
  if (typeof value !== "string" || value.length === 0 || value.includes("\0")) {
    throw new Error(`${name} must be a non-empty path`);
  }
  const subtree = value.endsWith("/**");
  const root = value === "/**" ? "/" : subtree ? value.slice(0, -3) : value;
  if (!root || /[*?\[\]{}]/.test(root) || (!subtree && value.includes("*"))) {
    throw new Error(
      `${name} supports exact paths and a terminal /** subtree only`,
    );
  }
  return value;
}

function validateOperations(value: unknown, name: string): Operation[] {
  if (
    !Array.isArray(value) ||
    value.length === 0 ||
    value.some((item) => !OPERATIONS.includes(item as Operation))
  ) {
    throw new Error(`${name} must be a non-empty subset of read and write`);
  }
  if (new Set(value).size !== value.length)
    throw new Error(`${name} must not contain duplicate operations`);
  return value as Operation[];
}

function validateCommandPattern(value: unknown, name: string): string {
  if (typeof value !== "string" || value.length === 0 || value.includes("\0")) {
    throw new Error(`${name} must be a non-empty command pattern`);
  }
  return value;
}

function validateReason(value: unknown, name: string): string | undefined {
  if (value === undefined) return undefined;
  if (
    typeof value !== "string" ||
    value.trim().length === 0 ||
    value.length > REASON_CHARACTERS_MAX ||
    value.includes("\0")
  ) {
    throw new Error(
      `${name} must be a non-empty string of at most ${REASON_CHARACTERS_MAX} characters`,
    );
  }
  return value;
}

/** Parses the strict ordered interceptor.json schema. */
export function parsePolicy(value: unknown): PermissionPolicy {
  const policy = onlyKeys(value, "policy", ["rules"]);
  if (!Array.isArray(policy.rules))
    throw new Error("policy.rules must be an array");

  return {
    rules: policy.rules.map((value, index) => {
      const name = `policy.rules[${index}]`;
      if (!isObject(value)) throw new Error(`${name} must be an object`);
      const rule =
        "bash" in value
          ? onlyKeys(value, name, ["bash", "action", "reason"])
          : onlyKeys(value, name, ["path", "operations", "action", "reason"]);
      if (!ACTIONS.includes(rule.action as PermissionAction)) {
        throw new Error(`${name}.action must be allow or deny`);
      }
      const reason = validateReason(rule.reason, `${name}.reason`);
      if ("bash" in rule)
        return {
          bash: validateCommandPattern(rule.bash, `${name}.bash`),
          action: rule.action as PermissionAction,
          ...(reason === undefined ? {} : { reason }),
        };
      if (!("path" in rule) || !("operations" in rule)) {
        throw new Error(`${name} must contain path, operations, and action`);
      }
      return {
        path: validateRulePath(rule.path, `${name}.path`),
        operations: validateOperations(rule.operations, `${name}.operations`),
        action: rule.action as PermissionAction,
        ...(reason === undefined ? {} : { reason }),
      };
    }),
  };
}

function scopedRules(
  policy: PermissionPolicy,
  scope: string,
): ScopedPermissionRule[] {
  return policy.rules.map((rule) => ({ ...rule, scope }));
}

/** Appends a validated last-match-wins rule group until its disposer is called. */
export function appendInterceptorRules(value: unknown, scope: string): () => void {
  const id = Symbol("interceptor-runtime-rules");
  runtimeRuleGroups.set(id, scopedRules(parsePolicy(value), scope));
  let active = true;
  return () => {
    if (!active) return;
    active = false;
    runtimeRuleGroups.delete(id);
  };
}

function appendedRuntimeRules(): ScopedPermissionRule[] {
  return [...runtimeRuleGroups.values()].flat();
}

async function loadPolicyFile(
  file: string,
  scope: string,
): Promise<ScopedPermissionRule[]> {
  try {
    return scopedRules(
      parsePolicy(JSON.parse(await fs.readFile(file, "utf8"))),
      scope,
    );
  } catch (error) {
    if (isNodeError(error, "ENOENT")) {
      try {
        await fs.lstat(file);
      } catch (statError) {
        if (isNodeError(statError, "ENOENT")) return [];
        throw statError;
      }
    }
    throw new Error(
      `${file}: ${error instanceof Error ? error.message : "unable to read interceptor policy"}`,
    );
  }
}

/** Loads global rules followed by trusted-project rules, preserving declaration order. */
export async function loadPolicies(options: {
  cwd: string;
  projectTrusted: boolean;
  globalConfigDir?: string;
}): Promise<PolicyLoad> {
  try {
    const rules: ScopedPermissionRule[] = [];
    const globalConfigDir =
      options.globalConfigDir ?? process.env.PI_CODING_AGENT_DIR;
    if (globalConfigDir) {
      // Global relative paths deliberately remain relative to the active cwd for compatibility.
      rules.push(
        ...(await loadPolicyFile(
          path.join(globalConfigDir, "interceptor.json"),
          options.cwd,
        )),
      );
    }
    if (options.projectTrusted) {
      rules.push(
        ...(await loadPolicyFile(
          path.join(options.cwd, ".pi", "interceptor.json"),
          options.cwd,
        )),
      );
    }
    return { rules };
  } catch (error) {
    return {
      error:
        error instanceof Error
          ? error.message
          : "Unable to read interceptor policy",
    };
  }
}

type SessionPolicyLoad = {
  rules: ScopedPermissionRule[];
  warning?: string;
};

// /reload creates a fresh extension instance, so last-valid policies live in a
// bounded process-global cache rather than the instance being replaced.
function filePolicyCache(): Map<string, ScopedPermissionRule[]> {
  const processState = globalThis as unknown as Record<PropertyKey, unknown>;
  const existing = processState[FILE_POLICY_CACHE_SYMBOL];
  if (existing instanceof Map) {
    return existing as Map<string, ScopedPermissionRule[]>;
  }
  const cache = new Map<string, ScopedPermissionRule[]>();
  processState[FILE_POLICY_CACHE_SYMBOL] = cache;
  return cache;
}

function filePolicyCacheKey(cwd: string, projectTrusted: boolean): string {
  return JSON.stringify([
    process.env.PI_CODING_AGENT_DIR ?? "",
    path.resolve(cwd),
    projectTrusted,
  ]);
}

function rememberFilePolicy(key: string, rules: ScopedPermissionRule[]): void {
  const cache = filePolicyCache();
  cache.delete(key);
  cache.set(key, rules);
  while (cache.size > FILE_POLICY_CACHE_ENTRIES_MAX) {
    const oldestKey = cache.keys().next().value as string | undefined;
    if (oldestKey === undefined) break;
    cache.delete(oldestKey);
  }
}

async function loadSessionPolicy(
  cwd: string,
  projectTrusted: boolean,
): Promise<SessionPolicyLoad> {
  const key = filePolicyCacheKey(cwd, projectTrusted);
  const loaded = await loadPolicies({ cwd, projectTrusted });
  if ("rules" in loaded) {
    rememberFilePolicy(key, loaded.rules);
    return loaded;
  }

  const lastValidRules = filePolicyCache().get(key);
  const fallback = lastValidRules ? "last valid policy" : "empty policy";
  return {
    rules: lastValidRules ?? [],
    warning: `Interceptor policy load failed (${loaded.error}); using ${fallback}.`,
  };
}

/** Resolves a path through its existing target or nearest existing parent. */
export async function canonicalizePath(
  target: string,
  cwd: string,
): Promise<string> {
  let unresolved = path.resolve(cwd, target);
  const suffix: string[] = [];
  while (true) {
    try {
      const existing = await fs.realpath(unresolved);
      return suffix.length === 0
        ? existing
        : path.join(existing, ...suffix.reverse());
    } catch (error) {
      if (!isNodeError(error, "ENOENT") && !isNodeError(error, "ENOTDIR"))
        throw error;
      const parent = path.dirname(unresolved);
      if (parent === unresolved)
        throw new Error(`No existing parent for ${target}`);
      suffix.push(path.basename(unresolved));
      unresolved = parent;
    }
  }
}

function expandPath(value: string, scope: string): string {
  if (value === "$CWD") return scope;
  if (value.startsWith("$CWD/")) return path.join(scope, value.slice(5));
  if (value === "~") return homedir();
  if (value.startsWith("~/")) return path.join(homedir(), value.slice(2));
  return path.resolve(scope, value);
}

function splitPattern(value: string): { root: string; subtree: boolean } {
  if (value === "/**") return { root: "/", subtree: true };
  return value.endsWith("/**")
    ? { root: value.slice(0, -3), subtree: true }
    : { root: value, subtree: false };
}

function matchesPath(target: string, root: string, subtree: boolean): boolean {
  return (
    target === root ||
    (subtree &&
      (root === path.parse(root).root
        ? target.startsWith(root)
        : target.startsWith(`${root}${path.sep}`)))
  );
}

async function ruleMatches(
  rule: ScopedPermissionRule,
  target: string,
  canonicalTarget: string,
): Promise<{ lexical: boolean; canonical: boolean }> {
  if (!("path" in rule)) return { lexical: false, canonical: false };
  const { root, subtree } = splitPattern(rule.path);
  const lexicalRoot = path.resolve(rule.scope, expandPath(root, rule.scope));
  const canonicalRoot = await canonicalizePath(lexicalRoot, rule.scope);
  return {
    lexical: matchesPath(target, lexicalRoot, subtree),
    canonical: matchesPath(canonicalTarget, canonicalRoot, subtree),
  };
}

export type PathDecision = { action: PermissionAction; reason?: string };

function isPermissionPolicy(
  value: readonly ScopedPermissionRule[] | PermissionPolicy,
): value is PermissionPolicy {
  return !Array.isArray(value);
}

/** Evaluates ordered rules. Allow rules require canonical matching to prevent symlink escapes. */
export async function pathDecision(
  rules: readonly ScopedPermissionRule[] | PermissionPolicy,
  tool: ToolName,
  target: string,
  cwd: string,
): Promise<PathDecision> {
  const scoped = isPermissionPolicy(rules) ? scopedRules(rules, cwd) : rules;
  const operation: Operation = tool === "read" ? "read" : "write";
  const lexicalTarget = path.resolve(cwd, target);
  const canonicalTarget = await canonicalizePath(target, cwd);
  let decision: PathDecision = {
    action: "deny",
    reason: `${target} does not match a permission rule`,
  };

  for (const rule of scoped) {
    if (!("path" in rule)) continue;
    if (!rule.operations.includes(operation)) continue;
    const matches = await ruleMatches(rule, lexicalTarget, canonicalTarget);
    if (
      rule.action === "allow"
        ? matches.canonical
        : matches.lexical || matches.canonical
    ) {
      decision = {
        action: rule.action,
        reason:
          rule.action === "deny" && rule.reason
            ? rule.reason
            : `${target} matches ${rule.path}`,
      };
    }
  }
  return decision;
}

function wildcardMatches(pattern: string, value: string): boolean {
  let source = "^";
  for (const char of pattern) {
    if (char === "*") source += ".*";
    else if (char === "?") source += ".";
    else source += "\\^$+.[\]{}()|".includes(char) ? `\\${char}` : char;
  }
  return new RegExp(`${source}$`, "s").test(value);
}

type TreeSitterModule = typeof import("web-tree-sitter");

let bashParser: Promise<TreeSitterParser> | undefined;

function dependencyFile(packageName: string, fileName: string, legacyFileName?: string): string {
  const nodeModules = process.env.PI_CONFIG_NODE_MODULES?.trim();
  if (nodeModules) {
    const preferredPath = path.join(nodeModules, packageName, fileName);
    // Keep development shells usable while Home Manager still exposes the
    // previous web-tree-sitter generation during an upgrade.
    if (!legacyFileName || existsSync(preferredPath)) return preferredPath;
    return path.join(nodeModules, packageName, legacyFileName);
  }
  return fileURLToPath(import.meta.resolve(`${packageName}/${fileName}`));
}

async function loadBashParser(): Promise<TreeSitterParser> {
  const nodeModules = process.env.PI_CONFIG_NODE_MODULES?.trim();
  const moduleSpecifier = nodeModules
    ? pathToFileURL(
        dependencyFile("web-tree-sitter", "web-tree-sitter.js", "tree-sitter.js"),
      ).href
    : "web-tree-sitter";
  const { Language, Parser } = (await import(moduleSpecifier)) as TreeSitterModule;
  await Parser.init({
    locateFile: () =>
      dependencyFile("web-tree-sitter", "web-tree-sitter.wasm", "tree-sitter.wasm"),
  });
  const language = await Language.load(
    dependencyFile("tree-sitter-bash", "tree-sitter-bash.wasm"),
  );
  return new Parser().setLanguage(language);
}

function getBashParser(): Promise<TreeSitterParser> {
  bashParser ??= loadBashParser();
  return bashParser;
}

type BashParseResult =
  | { commands: string[] }
  | { error: "invalid Bash syntax" | "Bash parser unavailable" };

async function inspectBashCommands(command: string): Promise<BashParseResult> {
  try {
    const parser = await getBashParser();
    parser.reset();
    const tree = parser.parse(command);
    if (!tree) return { error: "Bash parser unavailable" };
    try {
      if (tree.rootNode.hasError) return { error: "invalid Bash syntax" };
      const commands = tree.rootNode
        .descendantsOfType("command")
        .filter((node) => node !== null)
        .map((node) =>
          (node.parent?.type === "redirected_statement"
            ? node.parent.text
            : node.text
          ).trim(),
        )
        .filter(Boolean);
      return { commands };
    } finally {
      tree.delete();
    }
  } catch {
    return { error: "Bash parser unavailable" };
  }
}

/** Parses Bash syntax and returns every executable command source. */
export async function parseBashCommands(
  command: string,
): Promise<string[] | undefined> {
  const result = await inspectBashCommands(command);
  return "commands" in result ? result.commands : undefined;
}

/** Evaluates each command in a shell chain; every command must be allowed. */
export async function commandDecision(
  rules: readonly ScopedPermissionRule[] | PermissionPolicy,
  command: string,
  cwd: string,
): Promise<PathDecision> {
  const scoped = isPermissionPolicy(rules) ? scopedRules(rules, cwd) : rules;
  for (let index = scoped.length - 1; index >= 0; index -= 1) {
    const rule = scoped[index];
    if (!("bash" in rule)) continue;
    if (rule.bash === "*" && rule.action === "allow")
      return { action: "allow" };
    if (rule.action !== "allow") break;
  }
  const parsed = await inspectBashCommands(command);
  if ("error" in parsed) return { action: "deny", reason: parsed.error };
  const commands = parsed.commands;
  for (const parsed of commands) {
    let decision: PathDecision = {
      action: "deny",
      reason: `${parsed} does not match a Bash rule`,
    };
    for (const rule of scoped) {
      if ("bash" in rule && wildcardMatches(rule.bash, parsed)) {
        decision = {
          action: rule.action,
          reason:
            rule.action === "deny" && rule.reason
              ? rule.reason
              : `${parsed} matches ${rule.bash}`,
        };
      }
    }
    if (decision.action === "deny") return decision;
  }
  return { action: "allow" };
}

function eventPaths(event: unknown): string[] | undefined {
  if (!isObject(event)) return undefined;
  const input = isObject(event.input)
    ? event.input
    : isObject(event.params)
      ? event.params
      : undefined;
  if (typeof input?.path === "string") return [input.path];
  return undefined;
}

function block(reason: string) {
  return { block: true, reason: `Interceptor denied the tool call: ${reason}` };
}

export default function interceptor(pi: ExtensionAPI): void {
  let fileRules: ScopedPermissionRule[] = [];

  pi.on("session_start", async (_event, ctx) => {
    const loaded = await loadSessionPolicy(ctx.cwd, ctx.isProjectTrusted());
    fileRules = loaded.rules;
    if (!loaded.warning) return;

    if (ctx.hasUI) ctx.ui.notify(loaded.warning, "warning");
    else process.stderr.write(`${loaded.warning}\n`);
  });

  pi.on("before_agent_start", async (event) => ({
    systemPrompt: `${event.systemPrompt}\n\nThe interceptor applies ordered permissions to built-in read, edit, write, and bash calls. It is a tool-call guard, not an OS sandbox.`,
  }));

  pi.on("tool_call", async (event, ctx) => {
    const tool = DIRECT_FILE_TOOLS[event.toolName];
    if (!tool && event.toolName !== "bash") return;

    const rules = [...fileRules, ...appendedRuntimeRules()];

    if (event.toolName === "bash") {
      const input = isObject(event.input) ? event.input : undefined;
      if (typeof input?.command !== "string" || input.command.length === 0)
        return block("bash did not provide a command");
      const decision = await commandDecision(rules, input.command, ctx.cwd);
      if (decision.action === "allow") return;
      return block(decision.reason ?? input.command);
    }

    let targets: string[] | undefined;
    try {
      targets = eventPaths(event);
    } catch (error) {
      return block(
        `${tool} paths could not be parsed (${error instanceof Error ? error.message : "unknown error"})`,
      );
    }
    if (!targets || targets.length === 0)
      return block(`${tool} did not provide a path argument`);

    for (const target of targets) {
      let decision: PathDecision;
      try {
        decision = await pathDecision(rules, tool, target, ctx.cwd);
      } catch (error) {
        return block(
          `could not canonicalize ${target} (${error instanceof Error ? error.message : "unknown error"})`,
        );
      }
      if (decision.action === "allow") continue;
      return block(decision.reason ?? target);
    }
  });
}
