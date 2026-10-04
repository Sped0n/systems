import type {
    ExtensionAPI,
    ExtensionContext,
} from "@earendil-works/pi-coding-agent";

const PCOMMIT_ACTIVITY_CHARACTERS_MAX = 120;

function formatPcommitActivityValue(value: unknown): string {
    const singleLine =
        typeof value === "string" ? value.replace(/\s+/gu, " ").trim() : "";
    if (!singleLine) return "...";
    if (singleLine.length <= PCOMMIT_ACTIVITY_CHARACTERS_MAX) return singleLine;
    return `${singleLine.slice(0, PCOMMIT_ACTIVITY_CHARACTERS_MAX - 3)}...`;
}

export function formatPcommitToolActivity(
    toolName: string,
    args: Record<string, unknown>,
): string {
    if (toolName === "read")
        return `→ read ${formatPcommitActivityValue(args.path)}`;
    if (toolName === "rogt")
        return `→ rogt ${formatPcommitActivityValue(args.operation)}`;
    if (toolName === "grep")
        return `→ grep ${formatPcommitActivityValue(args.pattern)}`;
    if (toolName === "find" || toolName === "ls")
        return `→ ${toolName} ${formatPcommitActivityValue(args.path ?? args.pattern)}`;
    return `→ ${formatPcommitActivityValue(toolName)}`;
}

export function buildPcommitSystemPrompt(hint: string): string {
    return [
        "You write accurate Git commit messages for staged changes.",
        "Use rogt to inspect Git status, recent commit style, and staged diffs before answering.",
        "Start with rogt status, log, and diff with staged=true.",
        "Narrow large diffs by paths and use grep, find, and ls for repository discovery as needed.",
        "Use read when surrounding working-tree code helps explain the staged behavior.",
        "The final message must describe staged changes only, even when surrounding files contain other changes.",
        "Return only the commit message: an imperative subject of at most 72 characters, with no trailing period.",
        "Add a short body only when needed. Do not use Markdown fences, metadata, commentary, or sign-offs.",
        hint ? `Optional user hint: ${hint}` : "",
    ]
        .filter(Boolean)
        .join("\n");
}

function hasNoSessionFlag(argv: string[]): boolean {
    return argv.includes("--no-session");
}

async function git(
    pi: ExtensionAPI,
    cwd: string,
    args: string[],
    acceptedCodes: number[] = [0],
): Promise<string> {
    const result = await pi.exec("git", args, { cwd });
    if (!acceptedCodes.includes(result.code)) {
        throw new Error(
            result.stderr.trim() ||
                `git ${args[0]} failed with exit code ${result.code}`,
        );
    }
    return result.stdout;
}

function printAfterShutdown(message: string): void {
    process.once("exit", () => process.stderr.write(`pcommit: ${message}\n`));
    process.exitCode = 1;
}

export default function pcommit(pi: ExtensionAPI): void {
    pi.registerFlag("pcommit", {
        description: "Generate a staged commit message in a headless session",
        type: "boolean",
        default: false,
    });
    pi.registerFlag("pcommit-hint", {
        description: "Optional guidance for the generated commit message",
        type: "string",
    });

    let active = false;
    let writingMessageAnnounced = false;
    const fail = (ctx: ExtensionContext, error: unknown) => {
        printAfterShutdown(
            error instanceof Error ? error.message : String(error),
        );
        ctx.shutdown();
    };

    pi.on("before_agent_start", async (event) => {
        if (!active) return;
        const hint = String(pi.getFlag("pcommit-hint") ?? "").trim();
        return {
            systemPrompt: `${event.systemPrompt}\n\n${buildPcommitSystemPrompt(hint)}`,
        };
    });

    pi.on("tool_execution_start", async (event) => {
        if (!active) return;
        process.stderr.write(
            `pcommit: ${formatPcommitToolActivity(event.toolName, event.args)}\n`,
        );
    });

    pi.on("message_update", async (event) => {
        if (!active || writingMessageAnnounced) return;
        const updateType = event.assistantMessageEvent.type;
        if (updateType !== "text_start" && updateType !== "text_delta") return;
        writingMessageAnnounced = true;
        process.stderr.write("pcommit: writing commit message…\n");
    });

    pi.on("session_start", async (_event, ctx) => {
        if (pi.getFlag("pcommit") !== true) return;
        try {
            if (!hasNoSessionFlag(process.argv))
                throw new Error("--pcommit requires --no-session");
            if (ctx.hasUI) throw new Error("--pcommit requires --print");
            await git(pi, ctx.cwd, ["rev-parse", "--is-inside-work-tree"]);
            const staged = await pi.exec(
                "git",
                ["diff", "--cached", "--quiet"],
                {
                    cwd: ctx.cwd,
                },
            );
            if (staged.code === 0) throw new Error("No staged changes");
            if (staged.code !== 1) {
                throw new Error(
                    staged.stderr.trim() || "Could not inspect staged changes",
                );
            }

            pi.setActiveTools(["read", "grep", "find", "ls", "rogt"]);
            writingMessageAnnounced = false;
            active = true;
        } catch (error) {
            fail(ctx, error);
        }
    });
}
