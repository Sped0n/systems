import assert from "node:assert/strict";
import test from "node:test";

import { buildPcommitSystemPrompt } from "./index.ts";

test("buildPcommitSystemPrompt directs staged inspection and preserves the optional hint", () => {
	const prompt = buildPcommitSystemPrompt("focus on permission changes");
	assert.match(prompt, /git diff --cached --no-ext-diff --no-textconv/u);
	assert.match(prompt, /rg --no-config/u);
	assert.match(prompt, /describe staged changes only/u);
	assert.match(prompt, /Optional user hint: focus on permission changes/u);
});
