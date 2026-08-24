import { randomBytes } from "node:crypto";
import * as net from "node:net";

import {
  listSessionEndpoints,
  resolveSessionTarget,
  SessionTargetError,
} from "./discovery.ts";
import {
  ControlProtocolError,
  JsonLineDecoder,
  encodeJsonLine,
  validateControlRequest,
  validateControlResponse,
  type AssistantResult,
  type ControlRequest,
  type ControlResponse,
  type PasteResult,
  type SendOptions,
  type SendResult,
  type SessionEndpoint,
} from "./protocol.ts";

const DEFAULT_CONNECTION_TIMEOUT_MS = 1_000;
const DEFAULT_RESPONSE_TIMEOUT_MS = 5_000;

export interface SessionControlClient {
  list(options?: { cwd?: string }): Promise<SessionEndpoint[]>;
  send(target: string, options: SendOptions): Promise<SendResult>;
  paste(target: string, text: string): Promise<PasteResult>;
  getLastMessage(target: string): Promise<AssistantResult | null>;
}

export type SessionControlClientOptions = {
  controlDirectory: string;
  connectionTimeoutMs?: number;
  responseTimeoutMs?: number;
};

export type ClientControlErrorCode =
  | "disconnected"
  | "protocol_error"
  | "timeout"
  | "unreachable";

export class ClientControlError extends Error {
  readonly code: ClientControlErrorCode;
  readonly cause?: unknown;

  constructor(code: ClientControlErrorCode, message: string, cause?: unknown) {
    super(message);
    this.name = "ClientControlError";
    this.code = code;
    this.cause = cause;
  }
}

export class ServerControlError extends Error {
  readonly code: string;

  constructor(code: string, message: string) {
    super(message);
    this.name = "ServerControlError";
    this.code = code;
  }
}

function requestId(): string {
  return randomBytes(8).toString("hex");
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function requireObject(
  value: unknown,
  description: string,
): Record<string, unknown> {
  if (!isObject(value)) {
    throw new ClientControlError(
      "protocol_error",
      `${description} must be an object`,
    );
  }
  return value;
}

function requireString(value: unknown, description: string): string {
  if (typeof value !== "string") {
    throw new ClientControlError(
      "protocol_error",
      `${description} must be a string`,
    );
  }
  return value;
}

function requireAssistantResult(value: unknown): AssistantResult {
  const result = requireObject(value, "Assistant result");
  const text = requireString(result.text, "Assistant text");
  if (
    typeof result.timestamp !== "number" ||
    !Number.isFinite(result.timestamp)
  ) {
    throw new ClientControlError(
      "protocol_error",
      "Assistant timestamp must be a finite number",
    );
  }
  if (result.messageId !== undefined && typeof result.messageId !== "string") {
    throw new ClientControlError(
      "protocol_error",
      "Assistant messageId must be a string",
    );
  }
  return {
    text,
    timestamp: result.timestamp,
    ...(result.messageId === undefined ? {} : { messageId: result.messageId }),
  };
}

function responseData(response: ControlResponse): unknown {
  if (!response.success) {
    if (!response.error) {
      throw new ClientControlError(
        "protocol_error",
        "Failed response has no error",
      );
    }
    throw new ServerControlError(response.error.code, response.error.message);
  }
  return response.data;
}

function mapProtocolError(error: ControlProtocolError): ClientControlError {
  return new ClientControlError("protocol_error", error.message, error);
}

export class UnixSessionControlClient implements SessionControlClient {
  private readonly controlDirectory: string;
  private readonly connectionTimeoutMs: number;
  private readonly responseTimeoutMs: number;

  constructor(options: SessionControlClientOptions) {
    this.controlDirectory = options.controlDirectory;
    this.connectionTimeoutMs =
      options.connectionTimeoutMs ?? DEFAULT_CONNECTION_TIMEOUT_MS;
    this.responseTimeoutMs =
      options.responseTimeoutMs ?? DEFAULT_RESPONSE_TIMEOUT_MS;
  }

  async list(options: { cwd?: string } = {}): Promise<SessionEndpoint[]> {
    return await listSessionEndpoints(this.controlDirectory, options);
  }

  async send(target: string, options: SendOptions): Promise<SendResult> {
    const response = await this.request(target, {
      id: requestId(),
      type: "send",
      message: options.message,
      ...(options.sender === undefined ? {} : { sender: options.sender }),
    });
    const data = requireObject(responseData(response), "Send response data");
    if (data.accepted !== true) {
      throw new ClientControlError(
        "protocol_error",
        "Send response was not accepted",
      );
    }
    return { accepted: true };
  }

  async paste(target: string, text: string): Promise<PasteResult> {
    const response = await this.request(target, {
      id: requestId(),
      type: "paste",
      text,
    });
    const data = requireObject(responseData(response), "Paste response data");
    if (data.pasted !== true) {
      throw new ClientControlError(
        "protocol_error",
        "Paste response was not confirmed",
      );
    }
    return { pasted: true };
  }

  async getLastMessage(target: string): Promise<AssistantResult | null> {
    const response = await this.request(target, {
      id: requestId(),
      type: "last_message",
    });
    const data = requireObject(
      responseData(response),
      "Last message response data",
    );
    if (data.message === null) return null;
    return requireAssistantResult(data.message);
  }

  private async request(
    target: string,
    request: ControlRequest,
  ): Promise<ControlResponse> {
    const endpoints = await this.list();
    const endpoint = resolveSessionTarget(endpoints, target);
    try {
      validateControlRequest(request);
    } catch (error) {
      if (error instanceof ControlProtocolError) throw mapProtocolError(error);
      throw error;
    }
    return await this.exchange(endpoint, request);
  }

  private async exchange(
    endpoint: SessionEndpoint,
    request: ControlRequest,
  ): Promise<ControlResponse> {
    return await new Promise<ControlResponse>((resolve, reject) => {
      const socket = net.createConnection(endpoint.socketPath);
      const decoder = new JsonLineDecoder();
      let completed = false;
      let connected = false;
      let responseTimer: ReturnType<typeof setTimeout> | undefined;

      const connectionTimer = setTimeout(() => {
        fail(
          new ClientControlError(
            "timeout",
            "Timed out connecting to target session",
          ),
        );
      }, this.connectionTimeoutMs);
      const cleanup = () => {
        clearTimeout(connectionTimer);
        if (responseTimer) clearTimeout(responseTimer);
        socket.destroy();
      };
      const succeed = (response: ControlResponse) => {
        if (completed) return;
        completed = true;
        cleanup();
        resolve(response);
      };
      function fail(error: unknown) {
        if (completed) return;
        completed = true;
        cleanup();
        reject(error);
      }

      socket.once("connect", () => {
        connected = true;
        clearTimeout(connectionTimer);
        responseTimer = setTimeout(() => {
          fail(
            new ClientControlError(
              "timeout",
              "Timed out waiting for target response",
            ),
          );
        }, this.responseTimeoutMs);
        socket.write(encodeJsonLine(request));
      });
      socket.on("data", (chunk: Buffer) => {
        try {
          for (const value of decoder.push(chunk)) {
            const response = validateControlResponse(value);
            if (response.id !== request.id) {
              throw new ClientControlError(
                "protocol_error",
                "Received a response with a mismatched request id",
              );
            }
            succeed(response);
          }
        } catch (error) {
          fail(
            error instanceof ControlProtocolError
              ? mapProtocolError(error)
              : error,
          );
        }
      });
      socket.once("error", (error) => {
        fail(
          new ClientControlError(
            connected ? "disconnected" : "unreachable",
            connected
              ? `Target connection failed: ${error.message}`
              : `Target session is unreachable: ${error.message}`,
            error,
          ),
        );
      });
      socket.once("close", () => {
        if (!completed) {
          fail(
            new ClientControlError(
              "disconnected",
              "Target disconnected before responding",
            ),
          );
        }
      });
    });
  }
}

export { SessionTargetError };
