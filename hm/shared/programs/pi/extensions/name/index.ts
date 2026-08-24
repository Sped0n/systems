import type { UserMessage } from "@earendil-works/pi-ai";
import { complete, completeSimple } from "@earendil-works/pi-ai/compat";
import {
	CustomEditor,
	type ExtensionAPI,
	type ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { matchesKey, type EditorComponent } from "@earendil-works/pi-tui";

import { getModelTier, readModelTiers } from "../tier/model-tiers.ts";

const MAX_CONVERSATION_BYTES = 120_000;
const MAX_TITLE_LENGTH = 100;
const TITLE_SYSTEM_PROMPT = [
	"Generate a concise title for the supplied coding-agent conversation.",
	"Return only the title as one plain-text line.",
	"Do not use quotes, Markdown, a trailing period, or commentary.",
].join(" ");

function isRecord(value: unknown): value is Record<string, unknown> {
	return typeof value === "object" && value !== null && !Array.isArray(value);
}

function extractText(content: unknown): string {
	if (typeof content === "string") return content.trim();
	if (!Array.isArray(content)) return "";
	return content
		.flatMap((part) => {
			if (!isRecord(part) || part.type !== "text" || typeof part.text !== "string") return [];
			return [part.text];
		})
		.join("\n")
		.trim();
}

export function buildConversationText(entries: readonly unknown[]): string {
	const messages: string[] = [];
	for (const entry of entries) {
		if (!isRecord(entry) || entry.type !== "message" || !isRecord(entry.message)) continue;
		const role = entry.message.role;
		if (role !== "user" && role !== "assistant") continue;
		const text = extractText(entry.message.content);
		if (text) messages.push(`${role === "user" ? "User" : "Assistant"}: ${text}`);
	}
	return boundConversationText(messages.join("\n\n"));
}

export function boundConversationText(text: string, maxBytes = MAX_CONVERSATION_BYTES): string {
	const content = Buffer.from(text);
	if (content.byteLength <= maxBytes) return text;
	if (maxBytes <= 0) return "";
	const marker = Buffer.from("\n\n[Earlier and later conversation retained; middle omitted.]\n\n");
	if (maxBytes <= marker.byteLength) return content.subarray(0, maxBytes).toString("utf8");
	const remaining = Math.max(0, maxBytes - marker.byteLength);
	const headBytes = Math.ceil(remaining / 2);
	const tailBytes = Math.floor(remaining / 2);
	return Buffer.concat([
		content.subarray(0, headBytes),
		marker,
		content.subarray(content.byteLength - tailBytes),
	]).toString("utf8");
}

export function cleanGeneratedTitle(text: string): string {
	const title = text
		.replace(/<think>[\s\S]*?<\/think>\s*/gu, "")
		.split("\n")
		.map((line) => line.trim())
		.find(Boolean);
	if (!title) return "";
	return title.length > MAX_TITLE_LENGTH ? `${title.slice(0, MAX_TITLE_LENGTH - 3)}...` : title;
}

async function generateSessionTitle(ctx: ExtensionContext): Promise<string> {
	const conversation = buildConversationText(ctx.sessionManager.getBranch());
	if (!conversation) throw new Error("No conversation text found");

	const tier = getModelTier(await readModelTiers(), "economy");
	const model = ctx.modelRegistry.find(tier.provider, tier.model);
	if (!model) throw new Error(`Economy model not found: ${tier.provider}/${tier.model}`);
	const auth = await ctx.modelRegistry.getApiKeyAndHeaders(model);
	if (auth.ok === false) throw new Error(auth.error);

	const message: UserMessage = {
		role: "user",
		content: [{
			type: "text",
			text: `Generate a title for this conversation:\n\n<conversation>\n${conversation}\n</conversation>`,
		}],
		timestamp: Date.now(),
	};
	const request = tier.thinkingLevel === "off" ? complete : completeSimple;
	const response = await request(
		model,
		{ systemPrompt: TITLE_SYSTEM_PROMPT, messages: [message] },
		{
			apiKey: auth.apiKey,
			headers: auth.headers,
			...(tier.thinkingLevel === "off" ? {} : { reasoning: tier.thinkingLevel }),
		},
	);
	if (response.stopReason === "error" || response.stopReason === "aborted") {
		throw new Error(response.errorMessage || `Session title generation ${response.stopReason}`);
	}
	const title = cleanGeneratedTitle(
		response.content
			.filter((part): part is { type: "text"; text: string } => part.type === "text")
			.map((part) => part.text)
			.join(""),
	);
	if (!title) throw new Error("The economy model returned an empty session title");
	return title;
}

export function parseNameSubmission(text: string): string | undefined {
	const match = text.trim().match(/^\/name(?:\s+(.*))?$/u);
	return match ? (match[1] ?? "").trim() : undefined;
}

export function handleNameEditorSubmission(
	editor: Pick<EditorComponent, "addToHistory" | "getExpandedText" | "getText" | "setText">,
	data: string,
	onName: (args: string) => void,
): boolean {
	if (!matchesKey(data, "enter")) return false;
	const text = editor.getExpandedText?.() ?? editor.getText();
	const args = parseNameSubmission(text);
	if (args === undefined) return false;
	editor.addToHistory?.(text);
	editor.setText("");
	onName(args);
	return true;
}

class NameCommandEditor extends CustomEditor {
	constructor(
		tui: ConstructorParameters<typeof CustomEditor>[0],
		theme: ConstructorParameters<typeof CustomEditor>[1],
		keybindings: ConstructorParameters<typeof CustomEditor>[2],
		onName: (name: string) => void,
	) {
		super(tui, theme, keybindings);
		this.onName = onName;
	}

	private readonly onName: (args: string) => void;

	override handleInput(data: string): void {
		if (handleNameEditorSubmission(this, data, this.onName)) return;
		super.handleInput(data);
	}
}

async function nameSession(pi: ExtensionAPI, args: string, ctx: ExtensionContext): Promise<void> {
	const requestedName = args.trim();
	if (requestedName) {
		pi.setSessionName(requestedName);
		ctx.ui.notify(`Session named: ${pi.getSessionName() ?? requestedName}`, "info");
		return;
	}

	if (!ctx.isIdle()) {
		ctx.ui.notify("Wait for the current response to finish before generating a session name", "warning");
		return;
	}
	ctx.ui.notify("Generating session name...", "info");
	try {
		const generatedName = await generateSessionTitle(ctx);
		pi.setSessionName(generatedName);
		ctx.ui.notify(`Session named: ${pi.getSessionName() ?? generatedName}`, "info");
	} catch (error) {
		ctx.ui.notify(`Could not name session: ${error instanceof Error ? error.message : String(error)}`, "error");
	}
}

export default function sessionName(pi: ExtensionAPI): void {
	pi.on("session_start", (_event, ctx) => {
		if (ctx.mode !== "tui") return;
		ctx.ui.setEditorComponent((tui, theme, keybindings) =>
			new NameCommandEditor(tui, theme, keybindings, (args: string) => {
				void nameSession(pi, args, ctx);
			}),
		);
	});
}
