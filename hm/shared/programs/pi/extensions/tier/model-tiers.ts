import { readFile } from "node:fs/promises";
import { join } from "node:path";

import type { Api, Model, ThinkingLevel as ReasoningLevel } from "@earendil-works/pi-ai";
import {
  getAgentDir,
  type ExtensionContext,
} from "@earendil-works/pi-coding-agent";

export type ModelThinkingLevel = "off" | ReasoningLevel;

const THINKING_LEVELS: readonly ModelThinkingLevel[] = [
  "off",
  "minimal",
  "low",
  "medium",
  "high",
  "xhigh",
  "max",
];
const MODEL_TIER_FIELDS = new Set(["provider", "model", "thinkingLevel"]);

export interface ModelTier {
  provider: string;
  model: string;
  thinkingLevel: ModelThinkingLevel;
}

export type ModelTiers = Readonly<Record<string, ModelTier>>;

type ModelRegistry = Pick<ExtensionContext["modelRegistry"], "find" | "getApiKeyAndHeaders">;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/** Parse every named model tier strictly so configuration errors fail at one boundary. */
export function parseModelTiers(value: unknown, source = "tiers.json"): ModelTiers {
  if (!isRecord(value) || Object.keys(value).length === 0) {
    throw new Error(`${source} must define at least one model tier`);
  }

  const tiers: Record<string, ModelTier> = {};
  for (const [name, candidate] of Object.entries(value)) {
    if (!name || name.trim() !== name) {
      throw new Error(`${source} contains an invalid tier name`);
    }
    if (!isRecord(candidate)) {
      throw new Error(`${source}.${name} must be an object`);
    }
    const unknownField = Object.keys(candidate).find((field) => !MODEL_TIER_FIELDS.has(field));
    if (unknownField) {
      throw new Error(`${source}.${name} has unknown field ${unknownField}`);
    }
    const provider = typeof candidate.provider === "string" ? candidate.provider.trim() : "";
    const model = typeof candidate.model === "string" ? candidate.model.trim() : "";
    const thinkingLevel = candidate.thinkingLevel;
    if (!provider || !model || !THINKING_LEVELS.includes(thinkingLevel as ModelThinkingLevel)) {
      throw new Error(`${source}.${name} must define provider, model, and a valid thinkingLevel`);
    }
    tiers[name] = { provider, model, thinkingLevel: thinkingLevel as ModelThinkingLevel };
  }
  return tiers;
}

export async function readModelTiers(configPath = join(getAgentDir(), "tiers.json")): Promise<ModelTiers> {
  let value: unknown;
  try {
    value = JSON.parse(await readFile(configPath, "utf8"));
  } catch (error) {
    throw new Error(`Could not read ${configPath}: ${error instanceof Error ? error.message : String(error)}`);
  }
  return parseModelTiers(value, configPath);
}

export function getModelTier(tiers: ModelTiers, name: string): ModelTier {
  const tier = tiers[name];
  if (!tier) {
    const available = Object.keys(tiers).sort().join(", ");
    throw new Error(`Unknown model tier "${name}". Available tiers: ${available}`);
  }
  return tier;
}

export async function resolveModelTier(
  registry: ModelRegistry,
  name: string,
  tier: ModelTier,
): Promise<Model<Api>> {
  const model = registry.find(tier.provider, tier.model);
  if (!model) {
    throw new Error(`Model tier "${name}" model not found: ${tier.provider}/${tier.model}`);
  }
  const auth = await registry.getApiKeyAndHeaders(model);
  if (auth.ok === false) {
    throw new Error(`Model tier "${name}" authentication failed: ${auth.error}`);
  }
  return model;
}

export function findMatchingModelTiers(
  tiers: ModelTiers,
  model: Pick<Model<Api>, "provider" | "id"> | undefined,
  thinkingLevel: ModelThinkingLevel,
): string[] {
  if (!model) return [];
  return Object.entries(tiers)
    .filter(([, tier]) =>
      tier.provider === model.provider && tier.model === model.id && tier.thinkingLevel === thinkingLevel
    )
    .map(([name]) => name)
    .sort();
}
