import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

import {
	appendInterceptorRules,
	GIT_INSPECTION_BASH_POLICY,
} from "../interceptor/index.ts";
import { applyModelTier } from "../tier/index.ts";
import { getModelTier, readModelTiers } from "../tier/model-tiers.ts";

const PCOMMIT_ACTIVITY_CHARACTERS_MAX = 120;

function formatPcommitActivityValue(value: unknown): string {
	const singleLine = typeof value === "string" ? value.replace(/\s+/gu, " ").trim() : "";
	if (!singleLine) return "...";
	if (singleLine.length <= PCOMMIT_ACTIVITY_CHARACTERS_MAX) return singleLine;
	return `${singleLine.slice(0, PCOMMIT_ACTIVITY_CHARACTERS_MAX - 3)}...`;
}

export function formatPcommitToolActivity(toolName: string, args: Record<string, unknown>): string {
	if (toolName === "read") return `→ read ${formatPcommitActivityValue(args.path)}`;
	if (toolName === "bash") return `→ bash $ ${formatPcommitActivityValue(args.command)}`;
	return `→ ${formatPcommitActivityValue(toolName)}`;
}

export function buildPcommitSystemPrompt(hint: string): string {
	return [
		"You write accurate Git commit messages for staged changes.",
		"Use Bash to inspect Git status, recent commit style, and staged diffs before answering.",
		"Start with git status, git log, and git diff --cached --no-ext-diff --no-textconv.",
		"Narrow large diffs by path and use rg --no-config for repository search as needed.",
		"Use read when surrounding working-tree code helps explain the staged behavior.",
		"The final message must describe staged changes only, even when surrounding files contain other changes.",
		"Return only the commit message: an imperative subject of at most 72 characters, with no trailing period.",
		"Add a short body only when needed. Do not use Markdown fences, metadata, commentary, or sign-offs.",
		hint ? `Optional user hint: ${hint}` : "",
	].filter(Boolean).join("\n");
}

function hasNoSessionFlag(argv: string[]): boolean {
	return argv.includes("--no-session");
}

async function git(pi: ExtensionAPI, cwd: string, args: string[], acceptedCodes: number[] = [0]): Promise<string> {
	const result = await pi.exec("git", args, { cwd });
	if (!acceptedCodes.includes(result.code)) {
		throw new Error(result.stderr.trim() || `git ${args[0]} failed with exit code ${result.code}`);
	}
	return result.stdout;
}

function printAfterShutdown(message: string): void {
	process.once("exit", () => process.stderr.write(`pcommit: ${message}\n`));
	process.exitCode = 1;
}

export default function pcommit(pi: ExtensionAPI): void {
	pi.registerFlag("pcommit", {
		description: "Generate a staged commit message in a headless session",
		type: "boolean",
		default: false,
	});
	pi.registerFlag("pcommit-hint", {
		description: "Optional guidance for the generated commit message",
		type: "string",
	});

	let active = false;
	let writingMessageAnnounced = false;
	let releaseInspectionRules: (() => void) | undefined;

	const releaseRuntimeRules = () => {
		releaseInspectionRules?.();
		releaseInspectionRules = undefined;
	};

	const fail = (ctx: ExtensionContext, error: unknown) => {
		releaseRuntimeRules();
		printAfterShutdown(error instanceof Error ? error.message : String(error));
		ctx.shutdown();
	};

	pi.on("before_agent_start", async (event) => {
		if (!active) return;
		const hint = String(pi.getFlag("pcommit-hint") ?? "").trim();
		return { systemPrompt: `${event.systemPrompt}\n\n${buildPcommitSystemPrompt(hint)}` };
	});

	pi.on("tool_execution_start", async (event) => {
		if (!active) return;
		process.stderr.write(`pcommit: ${formatPcommitToolActivity(event.toolName, event.args)}\n`);
	});

	pi.on("message_update", async (event) => {
		if (!active || writingMessageAnnounced) return;
		const updateType = event.assistantMessageEvent.type;
		if (updateType !== "text_start" && updateType !== "text_delta") return;
		writingMessageAnnounced = true;
		process.stderr.write("pcommit: writing commit message…\n");
	});

	pi.on("session_start", async (_event, ctx) => {
		if (pi.getFlag("pcommit") !== true) return;
		try {
			if (!hasNoSessionFlag(process.argv)) throw new Error("--pcommit requires --no-session");
			if (ctx.hasUI) throw new Error("--pcommit requires --print");
			await git(pi, ctx.cwd, ["rev-parse", "--is-inside-work-tree"]);
			const staged = await pi.exec("git", ["diff", "--cached", "--quiet"], { cwd: ctx.cwd });
			if (staged.code === 0) throw new Error("No staged changes");
			if (staged.code !== 1) {
				throw new Error(staged.stderr.trim() || "Could not inspect staged changes");
			}

			const tiers = await readModelTiers();
			await applyModelTier(pi, ctx, "economy", getModelTier(tiers, "economy"));
			releaseInspectionRules = appendInterceptorRules(GIT_INSPECTION_BASH_POLICY, ctx.cwd);
			pi.setActiveTools(["read", "bash"]);
			writingMessageAnnounced = false;
			active = true;
		} catch (error) {
			fail(ctx, error);
		}
	});

	pi.on("session_shutdown", async () => {
		releaseRuntimeRules();
	});
}
