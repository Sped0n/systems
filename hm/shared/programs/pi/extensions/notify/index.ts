import path from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function notify(pi: ExtensionAPI): void {
    let focused = true;
    let stopFocusTracking: (() => void) | undefined;

    pi.on("session_start", (_event, ctx) => {
        stopFocusTracking?.();
        stopFocusTracking = undefined;
        focused = true;
        if (ctx.mode !== "tui") return;

        // Pi's alternate-screen UI consumes focus reports before onTerminalInput.
        // Observe stdin without consuming input or changing its terminal mode.
        let pending = "";
        const onData = (chunk: Buffer | string) => {
            const data = pending + chunk.toString();
            for (const match of data.matchAll(/\x1b\[([IO])/gu)) {
                focused = match[1] === "I";
            }
            // A focus report can span stdin chunks.
            pending = data.slice(-2);
        };
        process.stdin.on("data", onData);
        // Enable focus reporting in the immediate terminal (tmux, when present).
        process.stdout.write("\x1b[?1004h");
        stopFocusTracking = () => {
            process.stdin.off("data", onData);
            process.stdout.write("\x1b[?1004l");
        };
    });

    pi.on("agent_settled", (event, ctx) => {
        if (ctx.mode !== "tui" || focused || event.aborted) return;

        // Directory names are untrusted protocol data, not terminal commands.
        const project = (path.basename(ctx.cwd) || ctx.cwd).replace(
            /[\x00-\x1f\x7f-\x9f;]/gu,
            " ",
        );
        const notification = `\x1b]777;notify;Pi · ${project};Waiting for input\x07`;
        // tmux DCS passthrough doubles every ESC inside the payload.
        process.stdout.write(
            process.env.TMUX
                ? `\x1bPtmux;${notification.replaceAll("\x1b", "\x1b\x1b")}\x1b\\`
                : notification,
        );
    });

    pi.on("session_shutdown", () => {
        stopFocusTracking?.();
        stopFocusTracking = undefined;
        focused = true;
    });
}
