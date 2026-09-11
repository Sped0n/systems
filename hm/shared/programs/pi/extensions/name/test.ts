import assert from "node:assert/strict";
import test from "node:test";

import {
  boundConversationText,
  buildConversationText,
  cleanGeneratedTitle,
  handleNameEditorSubmission,
  parseNameSubmission,
} from "./index.ts";

test("buildConversationText includes only user and assistant text", () => {
  const text = buildConversationText([
    {
      type: "message",
      message: {
        role: "user",
        content: [{ type: "text", text: "Fix naming" }],
      },
    },
    {
      type: "message",
      message: {
        role: "assistant",
        content: [
          { type: "text", text: "Implemented it" },
          { type: "toolCall", name: "edit" },
        ],
      },
    },
    {
      type: "message",
      message: {
        role: "toolResult",
        content: [{ type: "text", text: "hidden" }],
      },
    },
    { type: "custom", data: "hidden" },
  ]);
  assert.equal(text, "User: Fix naming\n\nAssistant: Implemented it");
});

test("boundConversationText retains both ends", () => {
  const text = boundConversationText(`${"a".repeat(50)}${"b".repeat(50)}`, 70);
  assert.match(text, /^aaaa/u);
  assert.match(text, /middle omitted/u);
  assert.match(text, /bbbb$/u);
  assert.ok(Buffer.byteLength(text) <= 70);
});

test("cleanGeneratedTitle removes thinking and bounds OpenCode-style output", () => {
  assert.equal(
    cleanGeneratedTitle("<think>draft</think>\nUseful session title\nignored"),
    "Useful session title",
  );
  assert.equal(cleanGeneratedTitle("x".repeat(101)), `${"x".repeat(97)}...`);
});

test("parseNameSubmission accepts both supported forms only", () => {
  assert.equal(parseNameSubmission("/name"), "");
  assert.equal(parseNameSubmission("/name explicit title"), "explicit title");
  assert.equal(parseNameSubmission("/namespace"), undefined);
});

test("editor intercepts bare /name before Pi's built-in command", () => {
  let text = "/name";
  let submitted: string | undefined;
  const handled = handleNameEditorSubmission(
    {
      getText: () => text,
      setText: (value) => {
        text = value;
      },
      addToHistory: () => {},
    },
    "\r",
    (args) => {
      submitted = args;
    },
  );
  assert.equal(handled, true);
  assert.equal(submitted, "");
  assert.equal(text, "");
});
