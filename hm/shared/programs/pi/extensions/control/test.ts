import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { promises as fs } from "node:fs";
import * as path from "node:path";
import test from "node:test";

import { ClientControlError, UnixSessionControlClient } from "./client.ts";
import {
  ensureSessionControlDirectory,
  getSessionEndpointPaths,
  listSessionEndpoints,
  publishSessionEndpoint,
  resolveSessionTarget,
  SessionTargetError,
} from "./discovery.ts";
import { pasteEditorDraft } from "./index.ts";
import {
  ControlProtocolError,
  JsonLineDecoder,
  MAX_RECORD_BYTES,
  encodeJsonLine,
  validateControlRequest,
  validateControlResponse,
  type SendOptions,
  type SessionEndpoint,
} from "./protocol.ts";
import { SessionControlServer, type ControlledSession } from "./server.ts";

const sessionId = "0195f052-ef3b-7aaa-8000-0123456789ab";

function assertProtocolError(
  callback: () => unknown,
  code: ControlProtocolError["code"],
  message?: RegExp,
): void {
  assert.throws(callback, (error: unknown) => {
    assert.ok(error instanceof ControlProtocolError);
    assert.equal(error.code, code);
    if (message) assert.match(error.message, message);
    return true;
  });
}

test("control protocol accepts only one-off text operations", () => {
  const requests = [
    { id: "last-1", type: "last_message" },
    { id: "paste-1", type: "paste", text: "draft context" },
    {
      id: "send-1",
      type: "send",
      message: "Check this",
      sender: { sessionId, sessionName: "source" },
    },
  ];
  for (const request of requests) {
    assert.equal(validateControlRequest(request), request);
  }
  for (const type of ["subscribe", "summary", "abort", "clear"]) {
    assertProtocolError(
      () => validateControlRequest({ id: "x", type }),
      "invalid_record",
      /Unsupported request type/u,
    );
  }
  assertProtocolError(
    () => validateControlRequest({ id: "x", type: "paste", text: " " }),
    "invalid_record",
    /must not be empty/u,
  );
});

test("response validation preserves success and error invariants", () => {
  const success = {
    id: "send-1",
    type: "response",
    success: true,
    data: { accepted: true },
  };
  assert.equal(validateControlResponse(success), success);
  assertProtocolError(
    () => validateControlResponse({ ...success, type: "settled" }),
    "invalid_record",
    /must be response/u,
  );
  assertProtocolError(
    () =>
      validateControlResponse({ id: "x", type: "response", success: false }),
    "invalid_record",
    /must contain an error/u,
  );
});

test("JSONL framing handles fragmentation and bounded UTF-8 payloads", () => {
  const decoder = new JsonLineDecoder();
  const bytes = Buffer.from('{"message":"héllo"}\n{"ok":true}\n', "utf8");
  const splitInsideAccent = bytes.indexOf(Buffer.from("é")) + 1;
  assert.deepEqual(decoder.push(bytes.subarray(0, splitInsideAccent)), []);
  assert.deepEqual(decoder.push(bytes.subarray(splitInsideAccent)), [
    { message: "héllo" },
    { ok: true },
  ]);
  decoder.finish();
  assertProtocolError(
    () => encodeJsonLine("é".repeat(MAX_RECORD_BYTES)),
    "record_too_large",
  );
});

async function withTemporaryControlDirectory(
  callback: (controlDirectory: string, rootDirectory: string) => Promise<void>,
): Promise<void> {
  // Unix socket paths are short (107 bytes on Linux); Nix CI can provide a
  // much longer TMPDIR than the production agent path.
  const rootDirectory = await fs.mkdtemp("/tmp/pi-ctl-");
  const controlDirectory = path.join(rootDirectory, "session-control");
  try {
    await callback(controlDirectory, rootDirectory);
  } finally {
    await fs.rm(rootDirectory, { recursive: true, force: true });
  }
}

function endpointFor(
  controlDirectory: string,
  id: string,
  name: string | undefined,
  cwd: string,
): SessionEndpoint {
  return {
    sessionId: id,
    ...(name === undefined ? {} : { sessionName: name }),
    cwd,
    mode: "tui",
    pid: process.pid,
    state: "idle",
    startedAt: "2026-08-20T09:10:42.868Z",
    socketPath: getSessionEndpointPaths(controlDirectory, id).socketPath,
  };
}

test("discovery publishes owner-only metadata and resolves unique targets", async () => {
  await withTemporaryControlDirectory(
    async (controlDirectory, rootDirectory) => {
      const endpoint = endpointFor(
        controlDirectory,
        sessionId,
        "build",
        rootDirectory,
      );
      await publishSessionEndpoint(controlDirectory, endpoint);
      assert.equal((await fs.stat(controlDirectory)).mode & 0o777, 0o700);
      assert.equal(
        (
          await fs.stat(
            getSessionEndpointPaths(controlDirectory, sessionId).metadataPath,
          )
        ).mode & 0o777,
        0o600,
      );
      const listed = await listSessionEndpoints(controlDirectory, {
        cwd: rootDirectory,
        probe: async () => true,
      });
      assert.deepEqual(resolveSessionTarget(listed, "build"), endpoint);

      const duplicate = endpointFor(
        controlDirectory,
        "0195f052-ef3b-7aaa-8000-fedcba987654",
        "build",
        rootDirectory,
      );
      assert.throws(
        () => resolveSessionTarget([endpoint, duplicate], "build"),
        (error: unknown) => {
          assert.ok(error instanceof SessionTargetError);
          assert.equal(error.code, "target_ambiguous");
          return true;
        },
      );
    },
  );
});

test("external draft paste requests an immediate TUI render", () => {
  const calls: string[] = [];
  pasteEditorDraft(
    {
      pasteToEditor(text) {
        calls.push(`paste:${text}`);
      },
      setStatus(key, text) {
        calls.push(`status:${key}:${String(text)}`);
      },
    },
    "draft context",
  );
  assert.deepEqual(calls, [
    "paste:draft context",
    "status:pi-control-paste-refresh:undefined",
  ]);
});

class FakeControlledSession implements ControlledSession {
  readonly sent: SendOptions[] = [];
  readonly pasted: string[] = [];
  lastMessage = {
    text: "Latest result",
    timestamp: 123,
    messageId: "assistant-1",
  };

  constructor(private readonly endpoint: SessionEndpoint) {}

  describe(): SessionEndpoint {
    return this.endpoint;
  }

  async send(options: SendOptions) {
    this.sent.push(options);
    return { accepted: true as const };
  }

  async paste(text: string) {
    this.pasted.push(text);
    return { pasted: true as const };
  }

  getLastMessage() {
    return this.lastMessage;
  }
}

async function withControlServer(
  callback: (
    client: UnixSessionControlClient,
    session: FakeControlledSession,
    rootDirectory: string,
  ) => Promise<void>,
): Promise<void> {
  await withTemporaryControlDirectory(
    async (controlDirectory, rootDirectory) => {
      await ensureSessionControlDirectory(controlDirectory);
      const endpoint = endpointFor(
        controlDirectory,
        sessionId,
        "build",
        rootDirectory,
      );
      const session = new FakeControlledSession(endpoint);
      const server = new SessionControlServer({
        socketPath: endpoint.socketPath,
        session,
      });
      await server.start();
      await publishSessionEndpoint(controlDirectory, endpoint);
      const client = new UnixSessionControlClient({ controlDirectory });
      try {
        await callback(client, session, rootDirectory);
      } finally {
        await server.stop();
      }
    },
  );
}

test("client and server expose list, send, paste, and last as one-off operations", async () => {
  await withControlServer(async (client, session) => {
    assert.deepEqual(
      (await client.list()).map((endpoint) => endpoint.sessionName),
      ["build"],
    );
    assert.deepEqual(
      await client.send("build", {
        message: "Review this",
        sender: { sessionId, sessionName: "source" },
      }),
      { accepted: true },
    );
    assert.deepEqual(await client.paste("build", "draft text"), {
      pasted: true,
    });
    assert.deepEqual(await client.getLastMessage("build"), session.lastMessage);
    assert.deepEqual(session.sent, [
      {
        message: "Review this",
        sender: { sessionId, sessionName: "source" },
      },
    ]);
    assert.deepEqual(session.pasted, ["draft text"]);
  });
});

test("client rejects a mismatched response id", async () => {
  await withTemporaryControlDirectory(
    async (controlDirectory, rootDirectory) => {
      await ensureSessionControlDirectory(controlDirectory);
      const endpoint = endpointFor(
        controlDirectory,
        sessionId,
        "build",
        rootDirectory,
      );
      const server = await import("node:net").then(({ createServer }) =>
        createServer((socket) => {
          socket.once("data", () => {
            socket.end(
              encodeJsonLine({
                id: "wrong-id",
                type: "response",
                success: true,
                data: { message: null },
              }),
            );
          });
        }),
      );
      await new Promise<void>((resolve, reject) => {
        server.once("error", reject);
        server.listen(endpoint.socketPath, resolve);
      });
      await publishSessionEndpoint(controlDirectory, endpoint);
      const client = new UnixSessionControlClient({ controlDirectory });
      try {
        await assert.rejects(
          client.getLastMessage("build"),
          (error: unknown) => {
            assert.ok(error instanceof ClientControlError);
            assert.equal(error.code, "protocol_error");
            return true;
          },
        );
      } finally {
        await new Promise<void>((resolve) => server.close(() => resolve()));
      }
    },
  );
});

type CliResult = { code: number | null; stdout: string; stderr: string };

async function runControlCli(
  agentDirectory: string,
  args: string[],
  stdin?: string,
): Promise<CliResult> {
  return await new Promise<CliResult>((resolve, reject) => {
    const child = spawn(
      process.execPath,
      ["--import", "tsx", "scripts/pi-control.ts", ...args],
      {
        cwd: process.cwd(),
        env: {
          ...process.env,
          PI_CODING_AGENT_DIR: agentDirectory,
          PI_SESSION_ID: "",
        },
        stdio: ["pipe", "pipe", "pipe"],
      },
    );
    let stdout = "";
    let stderr = "";
    child.stdout.setEncoding("utf8").on("data", (chunk: string) => {
      stdout += chunk;
    });
    child.stderr.setEncoding("utf8").on("data", (chunk: string) => {
      stderr += chunk;
    });
    child.once("error", reject);
    child.once("close", (code) => resolve({ code, stdout, stderr }));
    child.stdin.end(stdin);
  });
}

test("CLI exposes only asynchronous text bridge commands", async () => {
  await withControlServer(async (_client, session, rootDirectory) => {
    const help = await runControlCli(rootDirectory, ["--help"]);
    assert.equal(help.code, 0);
    assert.match(help.stdout, /pi-control paste TARGET/u);
    assert.doesNotMatch(help.stdout, /watch|wait|summary|abort|clear/u);

    const listed = await runControlCli(rootDirectory, ["list", "--json"]);
    assert.equal(listed.code, 0, listed.stderr);
    assert.equal(
      (JSON.parse(listed.stdout) as SessionEndpoint[])[0].sessionName,
      "build",
    );

    const sent = await runControlCli(
      rootDirectory,
      ["send", "build", "--stdin", "--json"],
      "message text",
    );
    assert.equal(sent.code, 0, sent.stderr);
    assert.deepEqual(JSON.parse(sent.stdout), { accepted: true });

    const pasted = await runControlCli(
      rootDirectory,
      ["paste", "build", "--stdin", "--json"],
      "draft text",
    );
    assert.equal(pasted.code, 0, pasted.stderr);
    assert.deepEqual(JSON.parse(pasted.stdout), { pasted: true });

    const last = await runControlCli(rootDirectory, [
      "last",
      "build",
      "--json",
    ]);
    assert.equal(last.code, 0, last.stderr);
    assert.equal(
      (JSON.parse(last.stdout) as { text: string }).text,
      "Latest result",
    );
    assert.deepEqual(
      session.sent.map((item) => item.message),
      ["message text"],
    );
    assert.deepEqual(session.pasted, ["draft text"]);

    assert.equal(
      (await runControlCli(rootDirectory, ["watch", "build"])).code,
      2,
    );
  });
});
