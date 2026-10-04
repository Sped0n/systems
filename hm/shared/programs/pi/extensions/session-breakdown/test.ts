import assert from "node:assert/strict";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test, { type TestContext } from "node:test";

import { parseSessionFile } from "./index.ts";

async function parse(t: TestContext, entries: unknown[]) {
    const directory = await mkdtemp(join(tmpdir(), "pi-session-breakdown-"));
    t.after(() => rm(directory, { recursive: true, force: true }));
    const file = join(directory, "session.jsonl");
    await writeFile(
        file,
        [{ type: "session", timestamp: new Date().toISOString() }, ...entries]
            .map((entry) => JSON.stringify(entry))
            .join("\n"),
    );
    return parseSessionFile(file);
}

const modelChange = (modelId: string) => ({
    type: "model_change",
    provider: "provider",
    modelId,
});
const userMessage = { type: "message", message: { role: "user" } };

test("default and intermediate model selections do not count as used", async (t) => {
    const session = await parse(t, [
        modelChange("default"),
        userMessage,
        modelChange("intermediate"),
        modelChange("answered"),
        { type: "message", message: { role: "assistant" } },
    ]);
    assert.ok(session);
    assert.deepEqual([...session.modelsUsed], ["provider/answered"]);
    assert.equal(session.messages, 2);
});

test("sessions without any model response are excluded", async (t) => {
    for (const entries of [
        [userMessage],
        [modelChange("default"), userMessage],
    ]) {
        assert.equal(await parse(t, entries), null);
    }
});

test("legacy assistant roles still count", async (t) => {
    const session = await parse(t, [
        modelChange("legacy"),
        { type: "message", role: "assistant" },
    ]);
    assert.ok(session);
    assert.deepEqual([...session.modelsUsed], ["provider/legacy"]);
});
