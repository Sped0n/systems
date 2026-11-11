import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import footer from "./footer.ts";
import whimsical from "./whimsical.ts";

export default function uiExtension(pi: ExtensionAPI): void {
    footer(pi);
    whimsical(pi);
}
