import { readFileSync } from "node:fs";
import { dirname } from "node:path";

import {
    stripFrontmatter,
    type ExtensionAPI,
} from "@earendil-works/pi-coding-agent";
import { fuzzyFilter } from "@earendil-works/pi-tui";

const skillPrefix = "/skill:";

function splitSkillHeader(text: string) {
    const header = /^(?:\/skill:\S+(?: +|(?=\n|$)))+/.exec(text)?.[0] ?? "";
    return {
        tokens: header.match(/\S+/g) ?? [],
        rest: text.slice(header.length),
    };
}

export default function multiSkill(pi: ExtensionAPI) {
    const skillCommands = () =>
        pi.getCommands().filter((command) => command.source === "skill");
    const enabled = () => pi.getSettings().enableSkillCommands !== false;

    pi.on("session_start", (_event, ctx) => {
        ctx.ui.addAutocompleteProvider((current) => ({
            triggerCharacters: [...(current.triggerCharacters ?? []), "/"],
            async getSuggestions(lines, cursorLine, cursorCol, options) {
                const line = lines[cursorLine] ?? "";
                const match = /^((?:\/skill:\S+ +)+)(\/skill:(\S*))$/.exec(
                    line.slice(0, cursorCol),
                );
                if (enabled() && cursorLine === 0 && match) {
                    const otherCommands =
                        match[1]! + line.slice(cursorCol).replace(/^\S* */, "");
                    const selected = new Set(
                        splitSkillHeader(otherCommands).tokens,
                    );
                    const items = fuzzyFilter(
                        skillCommands().filter(
                            ({ name }) => !selected.has("/" + name),
                        ),
                        match[3]!,
                        (command) => command.name.slice("skill:".length),
                    ).map(({ name, description }) => ({
                        value: "/" + name,
                        label: "/" + name,
                        description,
                    }));
                    return items.length ? { items, prefix: match[2]! } : null;
                }
                return current.getSuggestions(
                    lines,
                    cursorLine,
                    cursorCol,
                    options,
                );
            },
            applyCompletion(lines, cursorLine, cursorCol, item, prefix) {
                // Built-in skill items omit the slash; only replace our inline items.
                if (
                    prefix.startsWith(skillPrefix) &&
                    item.value.startsWith(skillPrefix)
                ) {
                    const line = lines[cursorLine]!;
                    const completed =
                        line.slice(0, cursorCol - prefix.length) +
                        item.value +
                        " ";
                    const updated = [...lines];
                    updated[cursorLine] =
                        completed + line.slice(cursorCol).replace(/^\S* */, "");
                    return {
                        lines: updated,
                        cursorLine,
                        cursorCol: completed.length,
                    };
                }
                return current.applyCompletion(
                    lines,
                    cursorLine,
                    cursorCol,
                    item,
                    prefix,
                );
            },
            shouldTriggerFileCompletion:
                current.shouldTriggerFileCompletion?.bind(current),
        }));
    });

    pi.on("input", (event, ctx) => {
        if (event.source !== "interactive" || !enabled()) return;
        const { tokens, rest } = splitSkillHeader(event.text);
        if (tokens.length < 2) return;

        try {
            const commands = skillCommands();
            const blocks = [...new Set(tokens)].map((token) => {
                const name = token.slice(skillPrefix.length);
                const path = commands.find(
                    (command) => command.name === token.slice(1),
                )?.sourceInfo?.path;
                if (!path) throw new Error(`Unknown skill: ${name}`);
                const body = stripFrontmatter(
                    readFileSync(path, "utf8"),
                ).trim();
                return `<skill name="${name}" location="${path}">\nReferences are relative to ${dirname(path)}.\n\n${body}\n</skill>`;
            });
            return {
                action: "transform",
                text: [...blocks, rest.trimStart()]
                    .filter(Boolean)
                    .join("\n\n"),
            };
        } catch (error) {
            ctx.ui.notify(
                error instanceof Error ? error.message : String(error),
                "error",
            );
            if (!ctx.ui.getEditorText()) ctx.ui.setEditorText(event.text);
            return { action: "handled" };
        }
    });
}
