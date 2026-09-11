import type { Api, Model } from "@earendil-works/pi-ai";
import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";

import {
  findMatchingModelTiers,
  getModelTier,
  readModelTiers,
  resolveModelTier,
  type ModelThinkingLevel,
  type ModelTier,
  type ModelTiers,
} from "./model-tiers.ts";

const EXPLICIT_MODEL_ARGUMENTS = new Set([
  "--provider",
  "--model",
  "--thinking",
]);

type TierRuntime = Pick<ExtensionAPI, "setModel" | "setThinkingLevel">;
type TierContext = Pick<ExtensionContext, "modelRegistry">;

export function findTierFlagConflicts(argv: readonly string[]): string[] {
  return argv.filter(
    (argument, index) =>
      EXPLICIT_MODEL_ARGUMENTS.has(argument) && index + 1 < argv.length,
  );
}

export async function applyModelTier(
  runtime: TierRuntime,
  ctx: TierContext,
  name: string,
  tier: ModelTier,
): Promise<Model<Api>> {
  const model = await resolveModelTier(ctx.modelRegistry, name, tier);
  if (!(await runtime.setModel(model))) {
    throw new Error(`Model tier "${name}" has no available authentication`);
  }
  runtime.setThinkingLevel(tier.thinkingLevel);
  return model;
}

export function formatTierStatus(
  tiers: ModelTiers,
  model: Pick<Model<Api>, "provider" | "id"> | undefined,
  thinkingLevel: ModelThinkingLevel,
): string {
  const available = Object.keys(tiers).sort();
  const matching = findMatchingModelTiers(tiers, model, thinkingLevel);
  const active = matching.length > 0 ? matching.join(", ") : "custom";
  return `Active tier: ${active}. Available tiers: ${available.join(", ")}`;
}

async function switchToTier(
  pi: ExtensionAPI,
  ctx: ExtensionContext,
  name: string,
): Promise<void> {
  const tiers = await readModelTiers();
  const tier = getModelTier(tiers, name);
  await applyModelTier(pi, ctx, name, tier);
}

export default function modelTierExtension(pi: ExtensionAPI): void {
  pi.registerFlag("tier", {
    description: "Select a named model tier from tiers.json",
    type: "string",
  });

  pi.registerCommand("tier", {
    description: "Show or switch the current model tier",
    getArgumentCompletions: async (prefix) => {
      try {
        const names = Object.keys(await readModelTiers())
          .filter((name) => name.startsWith(prefix))
          .sort();
        return names.length > 0
          ? names.map((name) => ({ value: name, label: name }))
          : null;
      } catch {
        return null;
      }
    },
    handler: async (args, ctx) => {
      const requestedName = args.trim();
      try {
        if (!requestedName) {
          const tiers = await readModelTiers();
          ctx.ui.notify(
            formatTierStatus(tiers, ctx.model, pi.getThinkingLevel()),
            "info",
          );
          return;
        }
        if (!ctx.isIdle()) {
          ctx.ui.notify(
            "Wait for the current response to finish before switching model tiers",
            "warning",
          );
          return;
        }
        await switchToTier(pi, ctx, requestedName);
        ctx.ui.notify(`Model tier switched to ${requestedName}`, "info");
      } catch (error) {
        ctx.ui.notify(
          `Could not switch model tier: ${error instanceof Error ? error.message : String(error)}`,
          "error",
        );
      }
    },
  });

  pi.on("session_start", async (_event, ctx) => {
    const flag = pi.getFlag("tier");
    if (typeof flag !== "string" || !flag.trim()) return;

    const conflicts = findTierFlagConflicts(process.argv.slice(2));
    if (conflicts.length > 0) {
      ctx.ui.notify(
        `--tier cannot be combined with ${conflicts.join(", ")}`,
        "error",
      );
      ctx.shutdown();
      return;
    }

    try {
      await switchToTier(pi, ctx, flag.trim());
      ctx.ui.notify(`Model tier selected: ${flag.trim()}`, "info");
    } catch (error) {
      ctx.ui.notify(
        `Could not select model tier: ${error instanceof Error ? error.message : String(error)}`,
        "error",
      );
      ctx.shutdown();
    }
  });
}
