import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { chmod, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test, { type TestContext } from "node:test";
import { promisify } from "node:util";
import { validateToolArguments, type JsonObject } from "@earendil-works/pi-ai";
import type {
    ExtensionAPI,
    ExtensionToolContext,
} from "@earendil-works/pi-coding-agent";

import rogt, { inspectGit } from "./index.ts";

const executeFile = promisify(execFile);

async function repository(t: TestContext) {
    const cwd = await mkdtemp(path.join(tmpdir(), "pi-rogt-"));
    t.after(() => rm(cwd, { recursive: true, force: true }));
    const git = async (...args: string[]) =>
        (
            await executeFile("git", args, {
                cwd,
                env: {
                    ...process.env,
                    GIT_CONFIG_GLOBAL: "/dev/null",
                    GIT_CONFIG_NOSYSTEM: "1",
                },
            })
        ).stdout;
    await git("init", "--quiet");
    await git("config", "user.name", "Read-only Git Test");
    await git("config", "user.email", "rogt@example.invalid");
    await git("config", "commit.gpgsign", "false");
    await writeFile(path.join(cwd, "tracked.txt"), "original\n");
    await git("add", "tracked.txt");
    await git("commit", "--quiet", "-m", "Initial content");
    return { cwd, git };
}

function output(result: Awaited<ReturnType<typeof inspectGit>>) {
    return result.content[0].text;
}

test("inspection distinguishes staged, unstaged, untracked, and historical content without changing the index", async (t) => {
    const { cwd, git } = await repository(t);
    await writeFile(path.join(cwd, "tracked.txt"), "staged\n");
    await git("add", "tracked.txt");
    await writeFile(path.join(cwd, "tracked.txt"), "working\n");
    await writeFile(path.join(cwd, "untracked.txt"), "untracked\n");
    const indexBefore = await readFile(path.join(cwd, ".git/index"));
    assert.match(
        output(await inspectGit({ operation: "status" }, cwd)),
        /MM tracked.txt\n\?\? untracked.txt/u,
    );
    const staged = output(
        await inspectGit({ operation: "diff", staged: true }, cwd),
    );
    assert.match(staged, /\+staged/u);
    assert.doesNotMatch(staged, /\+working/u);
    assert.match(
        output(await inspectGit({ operation: "diff" }, cwd)),
        /\+working/u,
    );
    assert.match(
        output(await inspectGit({ operation: "log", limit: 1 }, cwd)),
        /Initial content/u,
    );
    assert.match(
        output(await inspectGit({ operation: "show" }, cwd)),
        /Initial content/u,
    );
    assert.equal(
        output(
            await inspectGit(
                { operation: "show", revision: "HEAD:tracked.txt" },
                cwd,
            ),
        ),
        "original\n",
    );
    assert.deepEqual(await readFile(path.join(cwd, ".git/index")), indexBefore);
});

test("paths are literal, logs paginate, and large output is explicitly truncated", async (t) => {
    const { cwd, git } = await repository(t);
    await writeFile(path.join(cwd, "a[1].txt"), "literal\n");
    await writeFile(path.join(cwd, "a1.txt"), "other\n");
    await git("add", ".");
    await git("commit", "--quiet", "-m", "Second content");
    await writeFile(path.join(cwd, "a[1].txt"), "selected\n");
    await writeFile(path.join(cwd, "a1.txt"), "not-selected\n");
    const diff = output(
        await inspectGit({ operation: "diff", paths: ["a[1].txt"] }, cwd),
    );
    assert.match(diff, /\+selected/u);
    assert.doesNotMatch(diff, /not-selected/u);
    const log = output(
        await inspectGit({ operation: "log", limit: 1, skip: 1 }, cwd),
    );
    assert.match(log, /Initial content/u);
    assert.doesNotMatch(log, /Second content/u);
    await writeFile(path.join(cwd, "tracked.txt"), "large line\n".repeat(3000));
    const result = await inspectGit(
        { operation: "diff", paths: ["tracked.txt"] },
        cwd,
    );
    assert.equal(result.details.truncated, true);
    assert.match(output(result), /Output truncated/u);
});

test("configured diff helpers and fsmonitor are not executed", async (t) => {
    const { cwd, git } = await repository(t);
    const helper = path.join(cwd, "helper");
    const marker = path.join(cwd, "helper-ran");
    await writeFile(
        helper,
        `#!${process.execPath}\nrequire('node:fs').writeFileSync(${JSON.stringify(marker)}, 'ran');\n`,
    );
    await chmod(helper, 0o755);
    await git("config", "diff.external", helper);
    await git("config", "diff.test.textconv", helper);
    await git("config", "core.fsmonitor", helper);
    await writeFile(path.join(cwd, ".gitattributes"), "*.txt diff=test\n");
    await writeFile(path.join(cwd, "tracked.txt"), "changed\n");
    await inspectGit({ operation: "status" }, cwd);
    assert.match(
        output(await inspectGit({ operation: "diff" }, cwd)),
        /\+changed/u,
    );
    assert.match(
        output(await inspectGit({ operation: "show" }, cwd)),
        /Initial content/u,
    );
    await assert.rejects(readFile(marker), { code: "ENOENT" });
});

test("invalid revisions, unsupported operations, failed Git commands, and cancellation are errors", async (t) => {
    const { cwd } = await repository(t);
    await assert.rejects(
        inspectGit({ operation: "show", revision: "--output=oops" }, cwd),
        /not an option/u,
    );
    await assert.rejects(
        inspectGit({ operation: "log", limit: 0 }, cwd),
        /limit/u,
    );
    await assert.rejects(
        inspectGit({ operation: "show", revision: "missing-revision" }, cwd),
    );
    await assert.rejects(
        inspectGit(
            { operation: "commit" } as unknown as Parameters<
                typeof inspectGit
            >[0],
            cwd,
        ),
        /Unsupported/u,
    );

    const controller = new AbortController();
    controller.abort();
    await assert.rejects(
        inspectGit({ operation: "status" }, cwd, controller.signal),
        { name: "AbortError" },
    );
});

test("registered tool requires activation and accepts provider-filled fields and nullable defaults", async (t) => {
    const { cwd, git } = await repository(t);
    await writeFile(path.join(cwd, "tracked.txt"), "staged\n");
    await git("add", "tracked.txt");
    await writeFile(path.join(cwd, "tracked.txt"), "working\n");
    type RegisteredTool = Parameters<ExtensionAPI["registerTool"]>[0];
    let tool: RegisteredTool | undefined;
    rogt({
        registerTool: (definition: RegisteredTool) => {
            tool = definition;
        },
    } as ExtensionAPI);
    assert.ok(tool);
    const registered = tool;
    assert.equal(registered.defaultActive, false);
    // Codemode must not reach this tool while inactive.
    assert.equal(registered.exposure ?? "direct", "direct");
    const call = async (args: JsonObject) => {
        const validated = validateToolArguments(registered, {
            type: "toolCall",
            id: "inspection",
            name: "rogt",
            arguments: args,
        });
        const result = await registered.execute(
            "inspection",
            validated,
            new AbortController().signal,
            undefined,
            { cwd } as ExtensionToolContext,
        );
        return result.content
            .filter((block) => block.type === "text")
            .map((block) => block.text)
            .join("\n");
    };
    // Responses providers may require every property even when Pi marks it optional.
    const filled = {
        format: "names",
        limit: 10,
        paths: [],
        revision: "HEAD",
        skip: 0,
        staged: false,
    };
    assert.match(
        await call({ ...filled, operation: "status" }),
        /MM tracked.txt/u,
    );
    assert.match(
        await call({ ...filled, operation: "log" }),
        /Initial content/u,
    );
    assert.match(
        await call({ ...filled, operation: "diff", staged: true }),
        /tracked.txt/u,
    );
    const nullable = {
        format: null,
        limit: null,
        paths: null,
        revision: null,
        skip: null,
        staged: null,
    };
    const unstaged = await call({ ...nullable, operation: "diff" });
    assert.match(unstaged, /-staged\n\+working/u);
    assert.doesNotMatch(unstaged, /-original/u);
    const staged = await call({ ...nullable, operation: "diff", staged: true });
    assert.match(staged, /-original\n\+staged/u);
    assert.doesNotMatch(staged, /\+working/u);
    assert.match(
        await call({ ...nullable, operation: "status" }),
        /MM tracked.txt/u,
    );
    assert.match(
        await call({ ...nullable, operation: "log" }),
        /Initial content/u,
    );
    assert.match(
        await call({ ...nullable, operation: "show" }),
        /Initial content/u,
    );
});

test("oversized output never masquerades as an empty result", async (t) => {
    const { cwd, git } = await repository(t);
    await writeFile(path.join(cwd, "large.txt"), "x".repeat(60_000));
    await git("add", "large.txt");
    const result = await inspectGit(
        { operation: "show", revision: ":large.txt" },
        cwd,
    );
    assert.equal(result.details.truncated, true);
    assert.match(output(result), /No complete lines fit/u);
    assert.doesNotMatch(output(result), /No matching changes/u);
    await writeFile(path.join(cwd, "large.txt"), "x".repeat(2 * 1024 * 1024));
    await git("add", "large.txt");
    await assert.rejects(
        inspectGit({ operation: "show", revision: ":large.txt" }, cwd),
        { code: "ERR_CHILD_PROCESS_STDIO_MAXBUFFER" },
    );
});
