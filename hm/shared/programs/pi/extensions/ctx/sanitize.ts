import { ANSI_RE, CTRL_RE } from "./constants.ts";

export const sanitize = (text: string): string =>
  text
    .replace(/\r\n/g, "\n")
    .replace(/\r/g, "\n")
    .replace(ANSI_RE, "")
    .replace(CTRL_RE, "");
