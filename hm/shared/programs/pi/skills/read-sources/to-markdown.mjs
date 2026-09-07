#!/usr/bin/env node

import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { basename, join } from "node:path";

function usage(code = 1) {
  console.error("Usage: node to-markdown.mjs <url-or-path> [--out <file> | --tmp]");
  process.exit(code);
}

function parseArgs(argv) {
  const result = { input: null, out: null, tmp: false };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--out") {
      const value = argv[++index];
      if (!value || value.startsWith("--")) usage();
      result[arg.slice(2)] = value;
    } else if (arg === "--tmp") {
      result.tmp = true;
    } else if (arg === "--help" || arg === "-h") {
      usage(0);
    } else if (arg.startsWith("--") || result.input) {
      usage();
    } else {
      result.input = arg;
    }
  }
  if (!result.input) usage();
  if (result.out && result.tmp) throw new Error("--out and --tmp are mutually exclusive");
  return result;
}

function isUrl(value) {
  return /^https?:\/\//i.test(value);
}

function temporaryMarkdownPath(input) {
  const directory = join(tmpdir(), "pi-document");
  mkdirSync(directory, { recursive: true });
  const name = (isUrl(input) ? basename(new URL(input).pathname) : basename(input)) || "document";
  return join(directory, `${name.replace(/[^a-z0-9._-]+/gi, "_")}-${Date.now()}.md`);
}

function convert(input) {
  const result = spawnSync("uvx", ["--from", "markitdown[pdf]", "markitdown", input], {
    encoding: "utf8",
    maxBuffer: 50 * 1024 * 1024,
  });
  if (result.error) throw new Error(`failed to run markitdown: ${result.error.message}`);
  if (result.status !== 0) throw new Error(`markitdown failed: ${(result.stderr || "").trim()}`);
  return result.stdout;
}

try {
  const args = parseArgs(process.argv.slice(2));
  if (!isUrl(args.input) && !existsSync(args.input)) throw new Error(`file not found: ${args.input}`);
  const markdown = convert(args.input);
  if (args.out) {
    writeFileSync(args.out, markdown, "utf8");
  } else if (args.tmp) {
    const temporaryPath = temporaryMarkdownPath(args.input);
    writeFileSync(temporaryPath, markdown, "utf8");
    process.stdout.write(`${temporaryPath}\n`);
  } else {
    process.stdout.write(markdown);
  }
} catch (error) {
  console.error(error.message);
  process.exit(1);
}
