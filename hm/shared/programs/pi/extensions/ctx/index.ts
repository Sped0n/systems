import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

import { buildBrief } from "./brief.ts";
import { registerRecall } from "./recall.ts";
import { maskConsumedToolResults } from "./view.ts";

export default function contextManagement(pi: ExtensionAPI) {
  registerRecall(pi);

  // Pi owns scheduling against the selected model, retained tool-call boundaries,
  // cancellation, persistence, overflow retry, and queued input. No actor-driven
  // compaction or synthetic continuation is needed.
  pi.on("session_before_compact", (event, ctx) => {
    try {
      if (!pi.getActiveTools().includes("recall"))
        throw new Error(
          "Recall must be active to compact into source pointers.",
        );
      return {
        compaction: {
          summary: buildBrief(event, ctx.model?.contextWindow ?? 0),
          firstKeptEntryId: event.preparation.firstKeptEntryId,
          tokensBefore: event.preparation.tokensBefore,
          details: {
            compactor: "ctx",
            format: "ui-v1",
            readFiles: [...event.preparation.fileOps.read],
            modifiedFiles: [
              ...new Set([
                ...event.preparation.fileOps.written,
                ...event.preparation.fileOps.edited,
              ]),
            ],
          },
        },
      };
    } catch (error) {
      if (!event.signal.aborted && ctx.hasUI)
        ctx.ui.notify(
          `Context compaction cancelled; history is intact: ${error instanceof Error ? error.message : String(error)}`,
          "error",
        );
      // Never silently fall through to a provider-backed summarizer on failure.
      return { cancel: true };
    }
  });

  pi.on("context", (event, ctx) => {
    // Do not replace evidence with unusable pointers when tools are restricted.
    if (!pi.getActiveTools().includes("recall")) return;
    return {
      messages: maskConsumedToolResults(
        event.messages,
        ctx.sessionManager.buildContextEntries(),
      ),
    };
  });
}
