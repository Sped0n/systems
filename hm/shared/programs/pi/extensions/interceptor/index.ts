import { existsSync, promises as fs } from "node:fs";
import { homedir } from "node:os";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import type { Parser as TreeSitterParser } from "web-tree-sitter";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export type Operation = "read" | "write";
export type PermissionAction = "allow" | "deny";
export type Matcher =
    | { path: string; operations: Operation[] }
    | { bash: string };
export type Rule = { matches: Matcher[] } & (
    | { action: PermissionAction; message?: string }
    | { action: "remind"; id: string; message: string; once: boolean }
);
export type Policy = { rules: Rule[] };
export type ScopedRule = Rule & {
    scope: string;
    source: string;
};
export type PolicyLoad = { rules: ScopedRule[] } | { error: string };
type ToolName = "read" | "edit" | "write";

const DIRECT_FILE_TOOLS: Record<string, ToolName> = {
    read: "read",
    edit: "edit",
    write: "write",
};
const OPERATIONS: Operation[] = ["read", "write"];
const TEXT_CHARACTERS_MAX = 500;
const FILE_POLICY_CACHE_ENTRIES_MAX = 32;
const INTERCEPTOR_STATE_SYMBOL = Symbol.for("pi.interceptor.state.v2");

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
    if (
        typeof value !== "string" ||
        value.length === 0 ||
        value.includes("\0")
    ) {
        throw new Error(`${name} must be a non-empty path`);
    }
    const subtree = value.endsWith("/**");
    const root = (
        value === "/**" ? "/" : subtree ? value.slice(0, -3) : value
    ).replace(/\$\{[A-Za-z_][A-Za-z0-9_]*\}/gu, "ENV");
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
    if (
        typeof value !== "string" ||
        value.length === 0 ||
        value.includes("\0")
    ) {
        throw new Error(`${name} must be a non-empty command pattern`);
    }
    return value;
}

function validateText(value: unknown, name: string): string | undefined {
    if (value === undefined) return undefined;
    if (
        typeof value !== "string" ||
        value.trim().length === 0 ||
        value.length > TEXT_CHARACTERS_MAX ||
        value.includes("\0")
    ) {
        throw new Error(
            `${name} must be a non-empty string of at most ${TEXT_CHARACTERS_MAX} characters`,
        );
    }
    return value;
}

function parseMatcher(value: unknown, name: string): Matcher {
    if (isObject(value) && "bash" in value) {
        const matcher = onlyKeys(value, name, ["bash"]);
        return { bash: validateCommandPattern(matcher.bash, name + ".bash") };
    }
    const matcher = onlyKeys(value, name, ["path", "operations"]);
    return {
        path: validateRulePath(matcher.path, name + ".path"),
        operations: validateOperations(
            matcher.operations,
            name + ".operations",
        ),
    };
}

/** Parses the strict ordered interceptor.json schema. */
export function parsePolicy(value: unknown): Policy {
    const policy = onlyKeys(value, "policy", ["rules"]);
    if (!Array.isArray(policy.rules))
        throw new Error("policy.rules must be an array");
    const ids = new Set<string>();
    return {
        rules: policy.rules.map((value, index): Rule => {
            const name = `policy.rules[${index}]`;
            if (!isObject(value)) throw new Error(name + " must be an object");
            const action = value.action;
            if (action !== "allow" && action !== "deny" && action !== "remind")
                throw new Error(
                    name + ".action must be allow, deny, or remind",
                );
            const rule = onlyKeys(
                value,
                name,
                action === "remind"
                    ? ["matches", "action", "id", "message", "once"]
                    : action === "deny"
                      ? ["matches", "action", "message"]
                      : ["matches", "action"],
            );
            if (!Array.isArray(rule.matches) || rule.matches.length === 0)
                throw new Error(name + ".matches must be a non-empty array");
            const matches = rule.matches.map((matcher, i) =>
                parseMatcher(matcher, name + ".matches[" + i + "]"),
            );
            const message = validateText(rule.message, name + ".message");
            if (action !== "remind")
                return {
                    matches,
                    action,
                    ...(message === undefined ? {} : { message }),
                };
            const id = validateText(rule.id, name + ".id");
            if (id === undefined) throw new Error(name + ".id is required");
            if (ids.has(id)) throw new Error(name + ".id duplicates " + id);
            ids.add(id);
            if (message === undefined)
                throw new Error(name + ".message is required");
            if (rule.once !== undefined && typeof rule.once !== "boolean")
                throw new Error(name + ".once must be a boolean");
            return { matches, action, id, message, once: rule.once !== false };
        }),
    };
}

function scopedRules(
    policy: Policy,
    scope: string,
    source = scope,
): ScopedRule[] {
    return policy.rules.map((rule) => ({
        ...rule,
        scope,
        source,
        matches: rule.matches.flatMap((matcher): Matcher[] => {
            if (!("path" in matcher)) return [matcher];
            const { root, subtree } = splitPattern(matcher.path);
            let missing = false;
            const expanded = root.replace(
                /\$\{([A-Za-z_][A-Za-z0-9_]*)\}/gu,
                (_match, name: string) => {
                    const replacement = process.env[name];
                    if (!replacement) {
                        missing = true;
                        return "";
                    }
                    // Values are literal paths, not another round of interpolation or globbing.
                    if (/[*?\[\]{}\0]/u.test(replacement))
                        throw new Error(
                            "invalid path in environment variable " + name,
                        );
                    return replacement;
                },
            );
            if (missing) return [];
            // Environment values are literal, including leading ~ or $CWD.
            const resolved = root.startsWith("${")
                ? path.resolve(scope, expanded)
                : expandPath(expanded, scope);
            return [
                {
                    ...matcher,
                    path: subtree
                        ? resolved === "/"
                            ? "/**"
                            : resolved + "/**"
                        : resolved,
                },
            ];
        }),
    }));
}

async function loadPolicyFile(
    file: string,
    scope: string,
): Promise<ScopedRule[]> {
    try {
        return scopedRules(
            parsePolicy(JSON.parse(await fs.readFile(file, "utf8"))),
            scope,
            file,
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
        const rules: ScopedRule[] = [];
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
    rules: ScopedRule[];
    warning?: string;
};

// /reload creates a fresh extension instance, so last-valid policies live in a
// bounded process-global cache rather than the instance being replaced.
type InterceptorState = {
    policies: Map<string, ScopedRule[]>;
    startupChecked: boolean;
};

function interceptorState(): InterceptorState {
    const processState = globalThis as unknown as Record<PropertyKey, unknown>;
    if (!processState[INTERCEPTOR_STATE_SYMBOL]) {
        processState[INTERCEPTOR_STATE_SYMBOL] = {
            policies: new Map(),
            startupChecked: false,
        } satisfies InterceptorState;
    }
    return processState[INTERCEPTOR_STATE_SYMBOL] as InterceptorState;
}

function filePolicyCacheKey(cwd: string, projectTrusted: boolean): string {
    return JSON.stringify([
        process.env.PI_CODING_AGENT_DIR ?? "",
        path.resolve(cwd),
        projectTrusted,
    ]);
}

function rememberFilePolicy(key: string, rules: ScopedRule[]): void {
    const cache = interceptorState().policies;
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

    const lastValidRules = interceptorState().policies.get(key);
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
    matcher: Extract<Matcher, { path: string }>,
    scope: string,
    target: string,
    canonicalTarget: string,
): Promise<{ lexical: boolean; canonical: boolean }> {
    const { root, subtree } = splitPattern(matcher.path);
    const lexicalRoot = root;
    const canonicalRoot = await canonicalizePath(lexicalRoot, scope);
    return {
        lexical: matchesPath(target, lexicalRoot, subtree),
        canonical: matchesPath(canonicalTarget, canonicalRoot, subtree),
    };
}

function denyReason(rule: ScopedRule, fallback: string): string {
    const { scope, source, message, ...matchedRule } = rule;
    const reason = message ?? fallback;
    const separator = /[.!?]$/u.test(reason) ? " " : ". ";
    return reason + separator + "Matched rule: " + JSON.stringify(matchedRule);
}

export type PermissionDecision = { action: PermissionAction; reason?: string };

function isPolicy(value: readonly ScopedRule[] | Policy): value is Policy {
    return !Array.isArray(value);
}

/** Allow requires canonical matching; deny also matches the lexical path. */
export async function pathDecision(
    rules: readonly ScopedRule[] | Policy,
    tool: ToolName,
    target: string,
    cwd: string,
): Promise<PermissionDecision> {
    const scoped = isPolicy(rules) ? scopedRules(rules, cwd) : rules;
    const operation: Operation = tool === "read" ? "read" : "write";
    const lexicalTarget = path.resolve(cwd, target);
    const canonicalTarget = await canonicalizePath(target, cwd);
    let decision: PermissionDecision = {
        action: "deny",
        reason: target + " does not match a permission rule",
    };
    for (const rule of scoped) {
        if (rule.action === "remind") continue;
        for (const matcher of rule.matches) {
            if (!("path" in matcher) || !matcher.operations.includes(operation))
                continue;
            const matches = await ruleMatches(
                matcher,
                rule.scope,
                lexicalTarget,
                canonicalTarget,
            );
            if (
                rule.action === "allow"
                    ? matches.canonical
                    : matches.lexical || matches.canonical
            ) {
                decision = {
                    action: rule.action,
                    reason:
                        rule.action === "deny"
                            ? denyReason(
                                  rule,
                                  target + " matches " + matcher.path,
                              )
                            : target + " matches " + matcher.path,
                };
                break;
            }
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

function dependencyFile(
    packageName: string,
    fileName: string,
    legacyFileName?: string,
): string {
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
              dependencyFile(
                  "web-tree-sitter",
                  "web-tree-sitter.js",
                  "tree-sitter.js",
              ),
          ).href
        : "web-tree-sitter";
    const { Language, Parser } = (await import(
        moduleSpecifier
    )) as TreeSitterModule;
    await Parser.init({
        locateFile: () =>
            dependencyFile(
                "web-tree-sitter",
                "web-tree-sitter.wasm",
                "tree-sitter.wasm",
            ),
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

/** Every parsed command must be allowed; reminders never grant permission. */
export async function commandDecision(
    rules: readonly ScopedRule[] | Policy,
    command: string,
    cwd: string,
): Promise<PermissionDecision> {
    const scoped = isPolicy(rules) ? scopedRules(rules, cwd) : rules;
    for (let index = scoped.length - 1; index >= 0; index -= 1) {
        const rule = scoped[index];
        if (
            rule.action === "remind" ||
            !rule.matches.some((matcher) => "bash" in matcher)
        )
            continue;
        if (
            rule.action === "allow" &&
            rule.matches.some(
                (matcher) => "bash" in matcher && matcher.bash === "*",
            )
        )
            return { action: "allow" };
        if (rule.action === "deny") break;
    }
    const parsed = await inspectBashCommands(command);
    if ("error" in parsed) return { action: "deny", reason: parsed.error };
    for (const command of parsed.commands) {
        let decision: PermissionDecision = {
            action: "deny",
            reason: command + " does not match a Bash rule",
        };
        for (const rule of scoped) {
            if (rule.action === "remind") continue;
            const matcher = rule.matches.find(
                (matcher) =>
                    "bash" in matcher && wildcardMatches(matcher.bash, command),
            );
            if (matcher && "bash" in matcher)
                decision = {
                    action: rule.action,
                    reason:
                        rule.action === "deny"
                            ? denyReason(
                                  rule,
                                  command + " matches " + matcher.bash,
                              )
                            : command + " matches " + matcher.bash,
                };
        }
        if (decision.action === "deny") return decision;
    }
    return { action: "allow" };
}

async function reminderMatches(
    rule: ScopedRule,
    tool: ToolName | "bash",
    value: string,
    cwd: string,
): Promise<boolean> {
    if (tool === "bash") {
        // Include the whole source to catch assignments/redirections with no command node.
        const parsed = await parseBashCommands(value);
        return rule.matches.some(
            (matcher) =>
                "bash" in matcher &&
                [value, ...(parsed ?? [])].some((command) =>
                    wildcardMatches(matcher.bash, command),
                ),
        );
    }
    const operation: Operation = tool === "read" ? "read" : "write";
    const lexical = path.resolve(cwd, value);
    const canonical = await canonicalizePath(value, cwd);
    for (const matcher of rule.matches) {
        if (!("path" in matcher) || !matcher.operations.includes(operation))
            continue;
        const matched = await ruleMatches(
            matcher,
            rule.scope,
            lexical,
            canonical,
        );
        if (matched.lexical || matched.canonical) return true;
    }
    return false;
}

function block(reason: string) {
    return {
        block: true,
        reason: `Interceptor denied the tool call: ${reason}`,
    };
}

export default async function interceptor(pi: ExtensionAPI): Promise<void> {
    let fileRules: ScopedRule[] = [];
    const delivered = new Set<string>();
    const reminderType = "interceptor-reminder";

    // Extension factories finish before the interactive UI starts. This is only
    // validation: project permissions are not activated until trust is known.
    const state = interceptorState();
    if (!state.startupChecked) {
        state.startupChecked = true;
        const preflight = await loadPolicies({
            cwd: process.cwd(),
            projectTrusted: true,
        });
        if ("error" in preflight)
            process.stderr.write(
                "Interceptor configuration warning: " +
                    preflight.error +
                    ". Invalid configuration will not be activated.\n",
            );
    }

    pi.on("session_start", async (_event, ctx) => {
        const loaded = await loadSessionPolicy(ctx.cwd, ctx.isProjectTrusted());
        fileRules = loaded.rules;
        delivered.clear();
        for (const entry of ctx.sessionManager.getBranch()) {
            if (entry.type === "compaction") delivered.clear();
            if (
                entry.type === "custom_message" &&
                entry.customType === reminderType &&
                isObject(entry.details) &&
                typeof entry.details.key === "string"
            )
                delivered.add(entry.details.key);
        }
        if (!loaded.warning) return;
        if (ctx.hasUI) ctx.ui.notify(loaded.warning, "warning");
        else process.stderr.write(loaded.warning + "\n");
    });

    pi.on("session_compact", async () => {
        delivered.clear();
    });

    pi.on("before_agent_start", async (event) => ({
        systemPrompt:
            event.systemPrompt +
            "\n\nThe interceptor applies ordered permissions and non-blocking reminders to built-in read, edit, write, and bash calls. It is a tool-call guard, not an OS sandbox.",
    }));

    pi.on("tool_call", async (event, ctx) => {
        const tool =
            event.toolName === "bash"
                ? "bash"
                : DIRECT_FILE_TOOLS[event.toolName];
        if (!tool) return;
        const input: Record<string, unknown> | undefined = isObject(event.input)
            ? event.input
            : undefined;
        const value = tool === "bash" ? input?.command : input?.path;
        if (
            typeof value !== "string" ||
            (tool === "bash" && value.length === 0)
        )
            return block(
                tool +
                    " did not provide a " +
                    (tool === "bash" ? "command" : "path argument"),
            );
        try {
            const decision =
                tool === "bash"
                    ? await commandDecision(fileRules, value, ctx.cwd)
                    : await pathDecision(fileRules, tool, value, ctx.cwd);
            if (decision.action === "deny")
                return block(decision.reason ?? value);
        } catch (error) {
            return block(
                tool +
                    " permission check failed (" +
                    (error instanceof Error ? error.message : "unknown error") +
                    ")",
            );
        }
        for (const rule of fileRules) {
            if (rule.action !== "remind") continue;
            const key = JSON.stringify([rule.source, rule.id]);
            if (rule.once && delivered.has(key)) continue;
            try {
                if (!(await reminderMatches(rule, tool, value, ctx.cwd)))
                    continue;
                // Another call can finish matching during the await above.
                if (rule.once && delivered.has(key)) continue;
                pi.sendMessage(
                    {
                        customType: reminderType,
                        content: rule.message,
                        display: false,
                        details: { key },
                    },
                    { triggerTurn: false },
                );
                // sendMessage is synchronous; no competing match can interleave here.
                delivered.add(key);
            } catch (error) {
                // Advisory failures must not turn allowed operations into denials.
                process.stderr.write(
                    "Interceptor reminder failed: " +
                        (error instanceof Error
                            ? error.message
                            : "unknown error") +
                        "\n",
                );
            }
        }
    });
}
