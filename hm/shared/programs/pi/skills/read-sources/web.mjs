#!/usr/bin/env node

import { writeFileSync } from "node:fs";

const USER_AGENT = "pi-coding-agent";

function jinaBase(name) {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is required`);
  return httpUrl(value).replace(/\/$/, "");
}

function usage(code = 1) {
  console.error("Usage: node web.mjs search <query> [--purpose <text>] [--limit <n>] [--read] [--json] [--out <file>]\n       node web.mjs read <url> [--json] [--out <file>]");
  process.exit(code);
}

function parseArgs(argv) {
  if (argv[0] === "--help" || argv[0] === "-h") usage(0);
  const [command, target, ...rest] = argv;
  if (!command || !target || !["search", "read"].includes(command)) usage();
  const options = { command, target, purpose: "general research", limit: 5, read: false, json: false, out: null };
  for (let index = 0; index < rest.length; index += 1) {
    const arg = rest[index];
    if (arg === "--read") options.read = true;
    else if (arg === "--json") options.json = true;
    else if (["--purpose", "--limit", "--out"].includes(arg)) {
      const value = rest[++index];
      if (!value || value.startsWith("--")) usage();
      options[arg.slice(2)] = arg === "--limit" ? Number(value) : value;
    } else if (arg === "--help" || arg === "-h") usage(0);
    else usage();
  }
  if (!Number.isInteger(options.limit) || options.limit < 1 || options.limit > 10) {
    throw new Error("--limit must be an integer from 1 through 10");
  }
  if (options.command === "read" && options.read) throw new Error("--read is only valid with search");
  return options;
}

function apiKey() {
  if (!process.env.JINA_API_KEY) throw new Error("JINA_API_KEY is required");
  return process.env.JINA_API_KEY;
}

function httpUrl(value) {
  const url = new URL(value);
  if (!/^https?:$/.test(url.protocol)) throw new Error("only HTTP(S) URLs are supported");
  return url.href;
}

async function request(url, accept) {
  const response = await fetch(url, {
    headers: {
      Authorization: `Bearer ${apiKey()}`,
      Accept: accept,
      "User-Agent": USER_AGENT,
      "X-Return-Format": accept.includes("json") ? "json" : "markdown",
    },
    signal: AbortSignal.timeout(60_000),
  });
  const body = await response.text();
  if (!response.ok) throw new Error(`Jina request failed (${response.status}): ${body}`);
  return body;
}

async function search(query, limit) {
  const base = jinaBase("JINA_SEARCH_SVIP_BASE");
  const body = await request(`${base}/?q=${encodeURIComponent(query)}`, "application/json");
  let parsed;
  try {
    parsed = JSON.parse(body);
  } catch {
    throw new Error("Jina Search returned non-JSON output");
  }
  const candidates = Array.isArray(parsed.data) ? parsed.data : Array.isArray(parsed.results) ? parsed.results : [];
  return candidates.slice(0, limit).map((item) => ({
    title: item.title || "Untitled",
    url: item.url || item.link,
    description: item.description || item.snippet || "",
    content: item.content || "",
  })).filter((item) => item.url);
}

async function read(url) {
  const source = httpUrl(url);
  const base = jinaBase("JINA_READER_BASE");
  return { url: source, markdown: await request(`${base}/${source}`, "text/plain") };
}

function formatSearch(results, pages) {
  const lines = results.map((result, index) => [
    `${index + 1}. ${result.title}`,
    result.url,
    result.description,
  ].filter(Boolean).join("\n"));
  for (const page of pages) lines.push(`\n## ${page.url}\n\n${page.markdown}`);
  return lines.join("\n\n");
}

try {
  const options = parseArgs(process.argv.slice(2));
  let data;
  if (options.command === "read") {
    data = await read(options.target);
  } else {
    const results = await search(options.target, options.limit);
    const pages = options.read ? await Promise.all(results.map((result) => read(result.url))) : [];
    data = { query: options.target, purpose: options.purpose, results, pages };
  }
  const output = options.json
    ? `${JSON.stringify(data, null, 2)}\n`
    : options.command === "read"
      ? data.markdown
      : `${formatSearch(data.results, data.pages)}\n`;
  if (options.out) writeFileSync(options.out, output, "utf8");
  else process.stdout.write(output);
} catch (error) {
  console.error(error.message);
  process.exit(1);
}
