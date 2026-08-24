#!/usr/bin/env node

import { parseArgs } from "node:util";

import {
  ClientControlError,
  ServerControlError,
  UnixSessionControlClient,
} from "../extensions/control/client.ts";
import {
  getSessionControlDirectory,
  resolveSessionTarget,
  SessionTargetError,
} from "../extensions/control/discovery.ts";
import {
  MAX_RECORD_BYTES,
  shortSessionId,
  type SessionEndpoint,
} from "../extensions/control/protocol.ts";

const EXIT_USAGE = 2;
const EXIT_TARGET = 3;
const EXIT_REJECTED = 4;
const EXIT_PROTOCOL = 5;
const EXIT_TIMEOUT = 124;

const HELP = `Usage:
  pi-control list [--cwd PATH] [--json]
  pi-control send TARGET [--message TEXT | --stdin] [--json]
  pi-control paste TARGET [--message TEXT | --stdin] [--json]
  pi-control last TARGET [--json]
`;

class UsageError extends Error {}

function parseCommandLine() {
  try {
    return parseArgs({
      args: process.argv.slice(2),
      allowPositionals: true,
      strict: true,
      options: {
        help: { type: "boolean", short: "h" },
        json: { type: "boolean" },
        cwd: { type: "string" },
        message: { type: "string" },
        stdin: { type: "boolean" },
      },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    if (process.argv.includes("--json")) {
      process.stderr.write(
        `${JSON.stringify({ success: false, error: { code: "usage", message } })}\n`,
      );
    } else {
      process.stderr.write(`pi-control: ${message}\n`);
    }
    process.exit(EXIT_USAGE);
  }
}

const parsed = parseCommandLine();

function usedOptions(): Set<string> {
  return new Set(
    Object.entries(parsed.values)
      .filter(([, value]) => value !== undefined && value !== false)
      .map(([name]) => name),
  );
}

function assertOptions(allowed: readonly string[]): void {
  const allowedSet = new Set(["json", "help", ...allowed]);
  for (const option of usedOptions()) {
    if (!allowedSet.has(option)) {
      throw new UsageError(`--${option} is not valid for this command`);
    }
  }
}

function requirePositionals(count: number, usage: string): string[] {
  if (parsed.positionals.length !== count) throw new UsageError(usage);
  return parsed.positionals;
}

async function readStandardInput(): Promise<string> {
  const chunks: Buffer[] = [];
  let bytes = 0;
  for await (const chunk of process.stdin) {
    const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
    bytes += buffer.byteLength;
    if (bytes > MAX_RECORD_BYTES) {
      throw new UsageError(`stdin exceeds ${MAX_RECORD_BYTES} bytes`);
    }
    chunks.push(buffer);
  }
  const text = Buffer.concat(chunks).toString("utf8");
  if (text.trim().length === 0) throw new UsageError("stdin must not be empty");
  return text;
}

async function messageArgument(command: "send" | "paste"): Promise<string> {
  if ((parsed.values.message === undefined) === (parsed.values.stdin !== true)) {
    throw new UsageError(
      `${command} requires exactly one of --message or --stdin`,
    );
  }
  const text = parsed.values.stdin
    ? await readStandardInput()
    : parsed.values.message!;
  if (text.trim().length === 0) {
    throw new UsageError(`${command} text must not be empty`);
  }
  return text;
}

function printJson(value: unknown): void {
  process.stdout.write(`${JSON.stringify(value)}\n`);
}

function printEndpoints(endpoints: SessionEndpoint[]): void {
  if (endpoints.length === 0) {
    process.stdout.write("No reachable sessions.\n");
    return;
  }
  const rows = endpoints.map((endpoint) => [
    endpoint.sessionName ?? "-",
    shortSessionId(endpoint.sessionId),
    endpoint.mode,
    endpoint.state,
    endpoint.cwd,
  ]);
  const headers = ["NAME", "ID", "MODE", "STATE", "CWD"];
  const widths = headers.map((header, index) =>
    Math.max(header.length, ...rows.map((row) => row[index].length)),
  );
  const line = (row: string[]) =>
    row
      .map((value, index) =>
        index === row.length - 1 ? value : value.padEnd(widths[index]),
      )
      .join("  ");
  process.stdout.write(`${line(headers)}\n${rows.map(line).join("\n")}\n`);
}

async function senderFor(
  client: UnixSessionControlClient,
  target: string,
): Promise<{ sessionId: string; sessionName?: string } | undefined> {
  const senderId = process.env.PI_SESSION_ID;
  if (!senderId) return undefined;
  const endpoints = await client.list();
  const sender = endpoints.find((endpoint) => endpoint.sessionId === senderId);
  if (!sender) return undefined;
  const targetEndpoint = resolveSessionTarget(endpoints, target);
  if (targetEndpoint.sessionId === sender.sessionId) return undefined;
  return {
    sessionId: sender.sessionId,
    ...(sender.sessionName === undefined
      ? {}
      : { sessionName: sender.sessionName }),
  };
}

async function run(): Promise<void> {
  if (parsed.values.help) {
    process.stdout.write(HELP);
    return;
  }
  const command = parsed.positionals[0];
  if (!command) throw new UsageError(HELP.trimEnd());
  const client = new UnixSessionControlClient({
    controlDirectory: getSessionControlDirectory(),
  });
  const json = parsed.values.json === true;

  switch (command) {
    case "list": {
      assertOptions(["cwd"]);
      requirePositionals(1, "Usage: pi-control list [--cwd PATH] [--json]");
      const endpoints = await client.list({ cwd: parsed.values.cwd });
      if (json) printJson(endpoints);
      else printEndpoints(endpoints);
      return;
    }
    case "send": {
      assertOptions(["message", "stdin"]);
      const [, target] = requirePositionals(
        2,
        "Usage: pi-control send TARGET [--message TEXT | --stdin]",
      );
      const result = await client.send(target, {
        message: await messageArgument("send"),
        sender: await senderFor(client, target),
      });
      if (json) printJson(result);
      else process.stdout.write("Accepted.\n");
      return;
    }
    case "paste": {
      assertOptions(["message", "stdin"]);
      const [, target] = requirePositionals(
        2,
        "Usage: pi-control paste TARGET [--message TEXT | --stdin]",
      );
      const result = await client.paste(
        target,
        await messageArgument("paste"),
      );
      if (json) printJson(result);
      else process.stdout.write("Pasted.\n");
      return;
    }
    case "last": {
      assertOptions([]);
      const [, target] = requirePositionals(
        2,
        "Usage: pi-control last TARGET [--json]",
      );
      const result = await client.getLastMessage(target);
      if (json) printJson(result);
      else {
        process.stdout.write(
          result ? `${result.text}\n` : "No complete assistant message.\n",
        );
      }
      return;
    }
    default:
      throw new UsageError(`Unknown command: ${command}\n${HELP.trimEnd()}`);
  }
}

function exitFor(error: unknown): number {
  if (
    error instanceof UsageError ||
    (error instanceof TypeError && error.message.includes("Unknown option"))
  ) {
    return EXIT_USAGE;
  }
  if (error instanceof SessionTargetError) return EXIT_TARGET;
  if (error instanceof ServerControlError) return EXIT_REJECTED;
  if (error instanceof ClientControlError) {
    if (error.code === "timeout") return EXIT_TIMEOUT;
    if (error.code === "protocol_error") return EXIT_PROTOCOL;
    if (error.code === "unreachable" || error.code === "disconnected") {
      return EXIT_TARGET;
    }
    return EXIT_REJECTED;
  }
  return EXIT_REJECTED;
}

try {
  await run();
} catch (error) {
  const message = error instanceof Error ? error.message : String(error);
  const code =
    error instanceof Error &&
    "code" in error &&
    typeof error.code === "string"
      ? error.code
      : "error";
  if (parsed.values.json) {
    process.stderr.write(
      `${JSON.stringify({ success: false, error: { code, message } })}\n`,
    );
  } else {
    process.stderr.write(`pi-control: ${message}\n`);
  }
  process.exitCode = exitFor(error);
}
