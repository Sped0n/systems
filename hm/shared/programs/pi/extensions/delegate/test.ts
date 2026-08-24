import assert from "node:assert/strict";
import test from "node:test";

import {
  boundDelegateText,
  buildDelegateArguments,
  DelegateJsonLineParser,
  formatDelegateToolCall,
  runDelegateChild,
} from "./index.ts";
import type { ModelTier } from "../tier/model-tiers.ts";

const economy: ModelTier = {
  provider: "example",
  model: "small",
  thinkingLevel: "low",
};

function argumentValue(args: readonly string[], flag: string): string | undefined {
  const index = args.indexOf(flag);
  return index === -1 ? undefined : args[index + 1];
}

test("delegate arguments isolate explore with interceptor and web resources", () => {
  const args = buildDelegateArguments("explore", "find the parser", economy, true, "/agent");
  assert.equal(argumentValue(args, "--tools"), "read,bash");
  assert.equal(argumentValue(args, "--extension"), "/agent/extensions/interceptor/index.ts");
  assert.equal(argumentValue(args, "--skill"), "/agent/skills/web/SKILL.md");
  assert.equal(argumentValue(args, "--provider"), "example");
  assert.equal(argumentValue(args, "--model"), "small");
  assert.equal(argumentValue(args, "--thinking"), "low");
  assert.ok(args.includes("--no-session"));
  assert.ok(args.includes("--approve"));
  assert.ok(args.includes("--no-extensions"));
  assert.ok(args.includes("--no-skills"));
  assert.ok(args.includes("--no-prompt-templates"));
  assert.ok(!args.includes("--no-context-files"));
  const delegatePrompt = argumentValue(args, "--append-system-prompt") ?? "";
  assert.match(delegatePrompt, /task-appropriate Markdown/);
  assert.match(delegatePrompt, /Gather observable facts and report the supporting evidence/);
  assert.match(delegatePrompt, /descriptive and directly supported by cited evidence/);
  assert.equal(args.at(-1), "Task: find the parser");
});

test("delegate arguments give bash no read tool or skills", () => {
  const args = buildDelegateArguments("bash", "run tests", economy, false, "/agent");
  assert.equal(argumentValue(args, "--tools"), "bash");
  assert.equal(args.includes("--skill"), false);
  assert.ok(args.includes("--no-approve"));
  assert.equal(args.filter((value) => value === "--extension").length, 1);
});

test("delegate JSONL parser handles fragmented final assistant messages", () => {
  const parser = new DelegateJsonLineParser();
  const event = JSON.stringify({
    type: "message_end",
    message: {
      role: "assistant",
      content: [{ type: "text", text: "evidence report" }],
      model: "small",
      stopReason: "stop",
    },
  });
  parser.push(event.slice(0, 17));
  parser.push(`${event.slice(17)}\n`);
  parser.finish();
  assert.deepEqual(parser.message, {
    text: "evidence report",
    model: "small",
    stopReason: "stop",
  });
  assert.equal(parser.protocolError, undefined);
});

test("delegate JSONL parser reports malformed records", () => {
  const parser = new DelegateJsonLineParser();
  parser.push("not-json\n");
  assert.equal(parser.protocolError, "Delegate emitted malformed JSONL output");
});

test("delegate JSONL parser emits tool execution starts from fragmented records", () => {
  const toolCalls: string[] = [];
  const parser = new DelegateJsonLineParser((toolName, args) => {
    toolCalls.push(formatDelegateToolCall(toolName, args));
  });
  const readEvent = JSON.stringify({
    type: "tool_execution_start",
    toolName: "read",
    args: { path: "src/parser.ts" },
  });
  const bashEvent = JSON.stringify({
    type: "tool_execution_start",
    toolName: "bash",
    args: { command: "rg parser\nsrc" },
  });

  parser.push(readEvent.slice(0, 23));
  parser.push(`${readEvent.slice(23)}\n${bashEvent}\n`);

  assert.deepEqual(toolCalls, ["→ read src/parser.ts", "→ bash $ rg parser src"]);
});

test("delegate tool activity is a bounded single line", () => {
  const activity = formatDelegateToolCall("bash", { command: `printf foo\n${"x".repeat(200)}` });
  assert.equal(activity.includes("\n"), false);
  assert.ok(activity.length <= 129);
  assert.ok(activity.endsWith("..."));
});

test("delegate report bounding preserves UTF-8 and marks truncation", () => {
  const bounded = boundDelegateText("alpha🙂omega", 12, "[…]");
  assert.equal(bounded.truncated, true);
  assert.ok(!bounded.text.includes("�"));
  assert.ok(Buffer.byteLength(bounded.text) <= 12);
  assert.ok(bounded.text.endsWith("[…]"));
});

test("delegate child captures only the final assistant message", async () => {
  const first = JSON.stringify({
    type: "message_end",
    message: { role: "user", content: [{ type: "text", text: "task" }] },
  });
  const final = JSON.stringify({
    type: "message_end",
    message: {
      role: "assistant",
      content: [{ type: "text", text: "final report" }],
      stopReason: "stop",
    },
  });
  const script = `process.stdout.write(${JSON.stringify(`${first}\n${final}\n`)})`;
  const result = await runDelegateChild(process.execPath, ["-e", script], process.cwd());
  assert.equal(result.exitCode, 0);
  assert.equal(result.message?.text, "final report");
  assert.equal(result.protocolError, undefined);
});

test("delegate child propagates an already-aborted signal", async () => {
  const controller = new AbortController();
  controller.abort();
  await assert.rejects(
    runDelegateChild(
      process.execPath,
      ["-e", "setInterval(() => {}, 1000)"],
      process.cwd(),
      controller.signal,
    ),
    /Delegate was aborted/,
  );
});

test("delegate child bounds stderr on process failure", async () => {
  const script = `process.stderr.write("x".repeat(40000)); process.exit(7)`;
  const result = await runDelegateChild(process.execPath, ["-e", script], process.cwd());
  assert.equal(result.exitCode, 7);
  assert.ok(Buffer.byteLength(result.stderr) <= 32 * 1024);
});
