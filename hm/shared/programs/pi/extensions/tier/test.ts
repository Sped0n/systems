import assert from "node:assert/strict";
import test from "node:test";

import type { Api, Model } from "@earendil-works/pi-ai";

import { applyModelTier, findTierFlagConflicts, formatTierStatus } from "./index.ts";
import {
  findMatchingModelTiers,
  getModelTier,
  parseModelTiers,
  resolveModelTier,
  type ModelTier,
} from "./model-tiers.ts";

const model = { provider: "example", id: "small" } as Model<Api>;
const economy: ModelTier = {
  provider: "example",
  model: "small",
  thinkingLevel: "low",
};

function modelRegistry(options: { found?: boolean; authenticated?: boolean } = {}) {
  return {
    find: () => options.found === false ? undefined : model,
    getApiKeyAndHeaders: async () => options.authenticated === false
      ? { ok: false as const, error: "missing key" }
      : { ok: true as const, apiKey: "key", headers: {} },
  };
}

test("model tiers parse dynamic strict entries", () => {
  const tiers = parseModelTiers({
    performance: {
      provider: "example",
      model: "large",
      thinkingLevel: "high",
    },
    economy,
  });

  assert.deepEqual(Object.keys(tiers), ["performance", "economy"]);
  assert.deepEqual(getModelTier(tiers, "economy"), economy);
  assert.throws(() => getModelTier(tiers, "missing"), /Available tiers: economy, performance/);
});

test("model tiers reject malformed configuration", () => {
  assert.throws(() => parseModelTiers({}), /at least one model tier/);
  assert.throws(
    () => parseModelTiers({ economy: { ...economy, extra: true } }),
    /unknown field extra/,
  );
  assert.throws(
    () => parseModelTiers({ economy: { ...economy, thinkingLevel: "extreme" } }),
    /valid thinkingLevel/,
  );
});

test("model tier resolution reports model and authentication failures", async () => {
  await assert.rejects(
    resolveModelTier(modelRegistry({ found: false }) as never, "economy", economy),
    /model not found/,
  );
  await assert.rejects(
    resolveModelTier(modelRegistry({ authenticated: false }) as never, "economy", economy),
    /authentication failed: missing key/,
  );
});

test("applyModelTier changes thinking only after model authentication succeeds", async () => {
  const calls: string[] = [];
  await applyModelTier(
    {
      async setModel(selected) {
        calls.push(`model:${selected.provider}/${selected.id}`);
        return true;
      },
      setThinkingLevel(level) {
        calls.push(`thinking:${level}`);
      },
    },
    { modelRegistry: modelRegistry() as never },
    "economy",
    economy,
  );
  assert.deepEqual(calls, ["model:example/small", "thinking:low"]);

  await assert.rejects(
    applyModelTier(
      {
        async setModel() {
          calls.push("unexpected model");
          return true;
        },
        setThinkingLevel() {
          calls.push("unexpected thinking");
        },
      },
      { modelRegistry: modelRegistry({ authenticated: false }) as never },
      "economy",
      economy,
    ),
    /authentication failed/,
  );
  assert.deepEqual(calls, ["model:example/small", "thinking:low"]);
});

test("tier status matches provider, model, and thinking level exactly", () => {
  const tiers = parseModelTiers({ economy });
  assert.deepEqual(findMatchingModelTiers(tiers, model, "low"), ["economy"]);
  assert.deepEqual(findMatchingModelTiers(tiers, model, "high"), []);
  assert.equal(formatTierStatus(tiers, model, "low"), "Active tier: economy. Available tiers: economy");
  assert.equal(formatTierStatus(tiers, model, "high"), "Active tier: custom. Available tiers: economy");
});

test("tier startup rejects explicit model configuration", () => {
  assert.deepEqual(
    findTierFlagConflicts(["--tier", "economy", "--model", "large", "--thinking", "high"]),
    ["--model", "--thinking"],
  );
  assert.deepEqual(findTierFlagConflicts(["--tier", "economy", "prompt"]), []);
});
