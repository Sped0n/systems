import { promises as fs } from "node:fs";
import * as net from "node:net";

import { setSessionSocketPermissions } from "./discovery.ts";
import {
  ControlProtocolError,
  JsonLineDecoder,
  encodeJsonLine,
  isValidRequestId,
  validateControlRequest,
  type AssistantResult,
  type ControlRequest,
  type ControlResponse,
  type PasteResult,
  type SendOptions,
  type SendResult,
  type SessionEndpoint,
} from "./protocol.ts";

const DEFAULT_CONNECTION_IDLE_TIMEOUT_MS = 30_000;
const DEFAULT_MAX_CONNECTIONS = 16;

export interface ControlledSession {
  describe(): SessionEndpoint;
  send(options: SendOptions): Promise<SendResult>;
  paste(text: string): Promise<PasteResult>;
  getLastMessage(): AssistantResult | null;
}

export class ControlledSessionError extends Error {
  readonly code: string;

  constructor(code: string, message: string) {
    super(message);
    this.name = "ControlledSessionError";
    this.code = code;
  }
}

export type SessionControlServerOptions = {
  socketPath: string;
  session: ControlledSession;
  connectionIdleTimeoutMs?: number;
  maxConnections?: number;
};

type ConnectionState = {
  socket: net.Socket;
  writer: SocketRecordWriter;
  requestId?: string;
};

/** One-request local JSONL server for a controlled Pi session. */
export class SessionControlServer {
  private readonly socketPath: string;
  private readonly session: ControlledSession;
  private readonly connectionIdleTimeoutMs: number;
  private readonly maxConnections: number;
  private readonly connections = new Map<net.Socket, ConnectionState>();
  private server?: net.Server;
  private stopping = false;

  constructor(options: SessionControlServerOptions) {
    this.socketPath = options.socketPath;
    this.session = options.session;
    this.connectionIdleTimeoutMs =
      options.connectionIdleTimeoutMs ?? DEFAULT_CONNECTION_IDLE_TIMEOUT_MS;
    this.maxConnections = options.maxConnections ?? DEFAULT_MAX_CONNECTIONS;
    if (
      !Number.isSafeInteger(this.maxConnections) ||
      this.maxConnections <= 0
    ) {
      throw new Error(
        "Session control maxConnections must be a positive integer",
      );
    }
  }

  async start(): Promise<void> {
    if (this.server)
      throw new Error("Session control server is already started");
    const endpoint = this.session.describe();
    if (endpoint.socketPath !== this.socketPath) {
      throw new Error(
        "Controlled session socketPath does not match server socketPath",
      );
    }
    this.stopping = false;
    const server = net.createServer((socket) => this.accept(socket));
    this.server = server;
    try {
      await new Promise<void>((resolve, reject) => {
        const onError = (error: Error) => {
          server.off("listening", onListening);
          reject(error);
        };
        const onListening = () => {
          server.off("error", onError);
          resolve();
        };
        server.once("error", onError);
        server.once("listening", onListening);
        server.listen(this.socketPath);
      });
      await setSessionSocketPermissions(this.socketPath);
    } catch (error) {
      this.server = undefined;
      server.close();
      throw error;
    }
  }

  async stop(): Promise<void> {
    if (this.stopping) return;
    this.stopping = true;
    const server = this.server;
    this.server = undefined;
    if (!server) {
      await fs.rm(this.socketPath, { force: true });
      return;
    }
    const closed = new Promise<void>((resolve) =>
      server.close(() => resolve()),
    );
    for (const connection of this.connections.values()) {
      connection.socket.end();
    }
    await closed;
    await fs.rm(this.socketPath, { force: true });
  }

  private accept(socket: net.Socket): void {
    if (this.stopping || this.connections.size >= this.maxConnections) {
      socket.destroy();
      return;
    }
    const state: ConnectionState = {
      socket,
      writer: new SocketRecordWriter(socket),
    };
    this.connections.set(socket, state);
    socket.setTimeout(this.connectionIdleTimeoutMs, () => socket.destroy());
    const decoder = new JsonLineDecoder();
    let handledRequest = false;

    socket.on("data", (chunk: Buffer) => {
      try {
        for (const value of decoder.push(chunk)) {
          if (handledRequest) {
            void this.writeError(
              state,
              state.requestId ?? "invalid",
              "invalid_request",
              "One request is allowed per connection",
            ).finally(() => socket.end());
            return;
          }
          handledRequest = true;
          socket.setTimeout(0);
          const request = validateControlRequest(value);
          state.requestId = request.id;
          void this.handleRequest(state, request);
        }
      } catch (error) {
        const code =
          error instanceof ControlProtocolError ? error.code : "invalid_record";
        const message =
          error instanceof Error ? error.message : "Invalid control request";
        void this.writeError(
          state,
          state.requestId ?? valueRequestId(chunk),
          code,
          message,
        ).finally(() => socket.end());
      }
    });
    socket.once("close", () => this.connections.delete(socket));
    socket.once("error", () => {});
  }

  private async handleRequest(
    connection: ConnectionState,
    request: ControlRequest,
  ): Promise<void> {
    try {
      switch (request.type) {
        case "last_message":
          await this.writeSuccess(connection, request.id, {
            message: this.session.getLastMessage(),
          });
          break;
        case "send":
          await this.writeSuccess(
            connection,
            request.id,
            await this.session.send({
              message: request.message,
              ...(request.sender === undefined
                ? {}
                : { sender: request.sender }),
            }),
          );
          break;
        case "paste":
          await this.writeSuccess(
            connection,
            request.id,
            await this.session.paste(request.text),
          );
          break;
      }
    } catch (error) {
      await this.writeError(
        connection,
        request.id,
        error instanceof ControlledSessionError
          ? error.code
          : "operation_rejected",
        error instanceof Error ? error.message : "Control operation failed",
      );
    } finally {
      connection.socket.end();
    }
  }

  private async writeSuccess(
    connection: ConnectionState,
    id: string,
    data: unknown,
  ): Promise<void> {
    await connection.writer.write({
      id,
      type: "response",
      success: true,
      data,
    });
  }

  private async writeError(
    connection: ConnectionState,
    id: string,
    code: string,
    message: string,
  ): Promise<void> {
    const response: ControlResponse = {
      id: isValidRequestId(id) ? id : "invalid",
      type: "response",
      success: false,
      error: { code, message },
    };
    await connection.writer.write(response);
  }
}

class SocketRecordWriter {
  private pending = Promise.resolve();
  private failed = false;

  constructor(private readonly socket: net.Socket) {}

  async write(record: unknown): Promise<void> {
    if (this.failed || this.socket.destroyed || this.socket.writableEnded)
      return;
    const encoded = encodeJsonLine(record);
    const write = this.pending.then(async () => {
      if (this.failed || this.socket.destroyed || this.socket.writableEnded)
        return;
      await new Promise<void>((resolve, reject) => {
        this.socket.write(encoded, (error) =>
          error ? reject(error) : resolve(),
        );
      });
    });
    this.pending = write.catch(() => {
      this.failed = true;
    });
    await write;
  }
}

function valueRequestId(chunk: Buffer): string {
  try {
    const newline = chunk.indexOf(0x0a);
    const value: unknown = JSON.parse(
      chunk.subarray(0, newline === -1 ? undefined : newline).toString("utf8"),
    );
    if (typeof value === "object" && value !== null && "id" in value) {
      const id = (value as { id?: unknown }).id;
      if (isValidRequestId(id)) return id;
    }
  } catch {
    // The request validator supplies the useful error.
  }
  return "invalid";
}
