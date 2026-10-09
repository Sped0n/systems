import type {
    ExtensionAPI,
    ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { FAST_MODE_STATUS } from "../footer/index.ts";

const FAST_MODE_ENTRY = "openai-fast-mode";

function isObject(value: unknown): value is Record<string, unknown> {
    return typeof value === "object" && value !== null && !Array.isArray(value);
}

function supportsOpenAIOptions(model: ExtensionContext["model"]): boolean {
    return Boolean(
        model?.id.toLowerCase().includes("gpt") &&
        (model.api === "openai-responses" ||
            model.api === "openai-codex-responses"),
    );
}

export default function openaiExtension(pi: ExtensionAPI): void {
    let fast = false;

    const updateStatus = (ctx: ExtensionContext): void => {
        ctx.ui.setStatus(
            FAST_MODE_STATUS,
            fast && supportsOpenAIOptions(ctx.model) ? "(fast)" : undefined,
        );
    };

    const restore = (ctx: ExtensionContext): void => {
        fast = false;
        for (const entry of ctx.sessionManager.getBranch()) {
            if (
                entry.type === "custom" &&
                entry.customType === FAST_MODE_ENTRY &&
                isObject(entry.data) &&
                typeof entry.data.enabled === "boolean"
            ) {
                fast = entry.data.enabled;
            }
        }
        updateStatus(ctx);
    };

    pi.on("session_start", (_event, ctx) => restore(ctx));
    pi.on("session_tree", (_event, ctx) => restore(ctx));
    pi.on("model_select", (_event, ctx) => updateStatus(ctx));

    pi.registerCommand("fast", {
        description: "Toggle priority requests for GPT Responses models",
        handler: async (_args, ctx) => {
            if (!supportsOpenAIOptions(ctx.model)) {
                ctx.ui.notify(
                    "/fast requires a GPT Responses model.",
                    "warning",
                );
                return;
            }
            const enabled = !fast;
            pi.appendEntry(FAST_MODE_ENTRY, { enabled });
            fast = enabled;
            updateStatus(ctx);
            ctx.ui.notify(
                enabled
                    ? "Fast mode on for subsequent requests (priority pricing may apply)."
                    : "Fast mode off for subsequent requests.",
                "info",
            );
        },
    });

    pi.on("before_provider_request", (event, ctx) => {
        if (!supportsOpenAIOptions(ctx.model) || !isObject(event.payload))
            return;
        // Copy at the request boundary: toggling during a stream must not
        // mutate the payload already handed to the provider.
        const payload = { ...event.payload };
        if (isObject(payload.reasoning)) {
            payload.reasoning = { ...payload.reasoning, summary: "concise" };
        }
        payload.text = {
            ...(isObject(payload.text) ? payload.text : {}),
            verbosity: "low",
        };
        if (fast) payload.service_tier = "priority";
        return payload;
    });
}
