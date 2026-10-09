import { execFile } from "node:child_process";
import { promisify } from "node:util";

import {
    truncateHead,
    type ExtensionAPI,
} from "@earendil-works/pi-coding-agent";
import { Type, type Static } from "typebox";

const paths = Type.Optional(
    Type.Union([Type.Array(Type.String({ minLength: 1 })), Type.Null()]),
);
const revision = Type.String({
    minLength: 1,
    description:
        "Git revision or range, never a command-line option. Null uses the operation's default. For show, revision:path reads a historical file.",
});
const format = Type.Optional(
    Type.Union(
        [
            Type.Literal("patch"),
            Type.Literal("stat"),
            Type.Literal("names"),
            Type.Null(),
        ],
        {
            description:
                "diff/show only: output format. Null defaults to patch; ignored by other operations.",
        },
    ),
);
const parameters = Type.Object(
    {
        operation: Type.Union([
            Type.Literal("status"),
            Type.Literal("diff"),
            Type.Literal("log"),
            Type.Literal("show"),
        ]),
        paths,
        revision: Type.Optional(Type.Union([revision, Type.Null()])),
        staged: Type.Optional(
            Type.Union([Type.Boolean(), Type.Null()], {
                description:
                    "diff only: true inspects staged changes. Null defaults to false; ignored by other operations.",
            }),
        ),
        format,
        limit: Type.Optional(
            Type.Union(
                [Type.Integer({ minimum: 1, maximum: 100 }), Type.Null()],
                {
                    description:
                        "log only: commit count. Null defaults to 10; ignored by other operations.",
                },
            ),
        ),
        skip: Type.Optional(
            Type.Union(
                [Type.Integer({ minimum: 0, maximum: 100_000 }), Type.Null()],
                {
                    description:
                        "log only: commits to skip. Null defaults to 0; ignored by other operations.",
                },
            ),
        ),
    },
    { additionalProperties: false },
);

type GitInspection = Static<typeof parameters>;
const executeFile = promisify(execFile);

/** Constructs only inspection commands; user values cannot become Git options. */
function gitArguments(request: GitInspection): string[] {
    if (!["status", "diff", "log", "show"].includes(request.operation)) {
        throw new Error("Unsupported Git inspection operation");
    }

    const args = [
        "--no-pager",
        "-c",
        "core.fsmonitor=false",
        "-c",
        "log.showSignature=false",
        request.operation,
    ];
    if (request.operation === "status") {
        args.push("--short", "--branch", "--untracked-files=all");
    } else {
        args.push("--no-ext-diff", "--no-textconv", "--color=never");
        if (request.operation === "log") {
            const limit = request.limit ?? 10;
            const skip = request.skip ?? 0;
            if (
                !Number.isInteger(limit) ||
                limit < 1 ||
                limit > 100 ||
                !Number.isInteger(skip) ||
                skip < 0 ||
                skip > 100_000
            ) {
                throw new Error("log requires limit 1–100 and skip 0–100000");
            }
            args.push(
                `--max-count=${limit}`,
                `--skip=${skip}`,
                "--format=medium",
                "--no-decorate",
            );
        } else {
            if (request.operation === "diff" && request.staged)
                args.push("--cached");
            if (request.format === "stat") args.push("--stat");
            else if (request.format === "names") args.push("--name-status");
        }
        const selectedRevision =
            request.revision ??
            (request.operation === "show" ? "HEAD" : undefined);
        args.push("--end-of-options");
        if (selectedRevision !== undefined) {
            if (
                !selectedRevision ||
                selectedRevision.startsWith("-") ||
                selectedRevision.includes("\0")
            ) {
                throw new Error(
                    "revision must be a non-empty Git revision, not an option",
                );
            }
            args.push(selectedRevision);
        }
    }
    args.push("--");
    for (const path of request.paths ?? []) {
        if (!path || path.includes("\0"))
            throw new Error("paths must be non-empty and contain no NUL bytes");
        args.push(path);
    }
    return args;
}

/** Reads Git output without a shell, index refresh writes, or configured diff helpers. */
export async function inspectGit(
    request: GitInspection,
    cwd: string,
    signal?: AbortSignal,
) {
    const env = { ...process.env };
    // Do not inherit injected Git config or diff helpers from the parent process.
    delete env.GIT_CONFIG_PARAMETERS;
    delete env.GIT_CONFIG_COUNT;
    delete env.GIT_EXTERNAL_DIFF;
    delete env.GIT_DIFF_OPTS;
    env.GIT_OPTIONAL_LOCKS = "0";
    env.GIT_LITERAL_PATHSPECS = "1";
    env.GIT_TERMINAL_PROMPT = "0";
    env.GIT_NO_LAZY_FETCH = "1";
    const { stdout } = await executeFile("git", gitArguments(request), {
        cwd,
        env,
        signal,
        encoding: "utf8",
        timeout: 30_000,
        maxBuffer: 1024 * 1024,
    });
    const output = truncateHead(stdout);
    return {
        content: [
            {
                type: "text" as const,
                text:
                    (output.content ||
                        (stdout
                            ? "No complete lines fit within the output limit."
                            : "No matching changes or entries.")) +
                    (output.truncated
                        ? "\n\n[Output truncated. Narrow paths/revisions, use stat or names, or paginate log with limit/skip.]"
                        : ""),
            },
        ],
        details: { operation: request.operation, truncated: output.truncated },
    };
}

export default function rogt(pi: ExtensionAPI): void {
    pi.registerTool({
        name: "rogt",
        label: "Read-only Git",
        // Review and pcommit opt in through setActiveTools; ordinary sessions
        // must not expose this tool directly or through codemode.
        defaultActive: false,
        description:
            "Inspect Git status, diffs, logs, and objects. Paths are literal repository paths. Diff defaults to unstaged changes; staged=true inspects the index. Log defaults to 10 commits; show defaults to HEAD and accepts revision:path for historical files. Output is capped at 2000 lines/50KB; commands exceeding 1MB fail, so narrow queries. No arbitrary Git flags or shell commands. Optional fields accept null for defaults; fields unrelated to the selected operation are ignored.",
        parameters,
        execute: (_id, request, signal, _update, ctx) =>
            inspectGit(request, ctx.cwd, signal),
    });
}
