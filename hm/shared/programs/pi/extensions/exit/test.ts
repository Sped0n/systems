import assert from "node:assert/strict";
import test from "node:test";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import exitAlias from "./index.ts";

test("exit command uses standard autocomplete and gracefully shuts down", async () => {
  let command:
    | {
        description: string;
        handler: (args: string, ctx: { shutdown(): void }) => unknown;
      }
    | undefined;
  const pi = {
    registerCommand(name: string, definition: typeof command) {
      assert.equal(name, "exit");
      command = definition;
    },
  } as unknown as ExtensionAPI;

  exitAlias(pi);

  assert.ok(command);
  assert.equal(command.description, "Quit pi");
  let shutdown = false;
  await command.handler("", {
    shutdown: () => {
      shutdown = true;
    },
  });
  assert.equal(shutdown, true);
});
