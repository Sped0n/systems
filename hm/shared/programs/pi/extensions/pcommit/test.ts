import assert from "node:assert/strict";
import test from "node:test";

import {
  buildPcommitSystemPrompt,
  formatPcommitToolActivity,
} from "./index.ts";

test("buildPcommitSystemPrompt directs staged inspection and preserves the optional hint", () => {
  const prompt = buildPcommitSystemPrompt("focus on permission changes");
  assert.match(prompt, /git diff --cached --no-ext-diff --no-textconv/u);
  assert.match(prompt, /rg --no-config/u);
  assert.match(prompt, /describe staged changes only/u);
  assert.match(prompt, /Optional user hint: focus on permission changes/u);
});

test("pcommit tool activity is a bounded single line", () => {
  assert.equal(
    formatPcommitToolActivity("read", {
      path: "hm/shared/programs/pi/default.nix",
    }),
    "→ read hm/shared/programs/pi/default.nix",
  );
  const bashActivity = formatPcommitToolActivity("bash", {
    command: `git diff --cached\n${"x".repeat(200)}`,
  });
  assert.equal(bashActivity.includes("\n"), false);
  assert.ok(bashActivity.length <= 129);
  assert.ok(bashActivity.endsWith("..."));
});
