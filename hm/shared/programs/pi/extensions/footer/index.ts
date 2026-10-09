import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { FooterComponent } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

// These statuses occupy dedicated footer slots rather than the status line.
export const SESSION_MARKER_STATUS = "footer-session-marker";
export const FAST_MODE_STATUS = "footer-openai-fast";

export default function footerExtension(pi: ExtensionAPI): void {
    pi.on("session_start", (_event, ctx) => {
        if (ctx.mode !== "tui") return;
        ctx.ui.setFooter((tui, theme, footerData) => {
            const session = {
                get state() {
                    const model = ctx.model;
                    const fast = footerData
                        .getExtensionStatuses()
                        .get(FAST_MODE_STATUS);
                    return {
                        // Decorate only the footer's view, never the request model.
                        model:
                            model && fast
                                ? {
                                      ...model,
                                      id: `${model.id} ${theme.fg("accent", fast)}`,
                                  }
                                : model,
                        thinkingLevel: ctx.thinkingLevel,
                    };
                },
                sessionManager: ctx.sessionManager,
                getContextUsage: () => ctx.getContextUsage(),
                modelRuntime: { isUsingSubscription: () => false },
            } as unknown as ConstructorParameters<typeof FooterComponent>[0];
            const data = {
                getGitBranch: () => footerData.getGitBranch(),
                getAvailableProviderCount: () =>
                    footerData.getAvailableProviderCount(),
                onBranchChange: (callback: () => void) =>
                    footerData.onBranchChange(callback),
                getExtensionStatuses: () =>
                    new Map(
                        [...footerData.getExtensionStatuses()].filter(
                            ([key]) =>
                                key !== SESSION_MARKER_STATUS &&
                                key !== FAST_MODE_STATUS,
                        ),
                    ),
            };
            const footer = new FooterComponent(session, data);
            const unsubscribe = footerData.onBranchChange(() =>
                tui.requestRender(),
            );
            return {
                render(width: number): string[] {
                    const lines = footer.render(width);
                    const marker = footerData
                        .getExtensionStatuses()
                        .get(SESSION_MARKER_STATUS);
                    if (!marker) return lines;
                    const right = truncateToWidth(
                        theme.fg("dim", marker),
                        width,
                        "",
                    );
                    const rightWidth = visibleWidth(right);
                    const left = truncateToWidth(
                        lines[0] ?? "",
                        Math.max(0, width - rightWidth - 1),
                        "",
                    );
                    const padding = " ".repeat(
                        Math.max(0, width - visibleWidth(left) - rightWidth),
                    );
                    return [left + padding + right, ...lines.slice(1)];
                },
                invalidate: () => footer.invalidate(),
                dispose() {
                    unsubscribe();
                    footer.dispose();
                },
            };
        });
    });
}
