/** Maximum UTF-8 bytes in one JSON payload, excluding its line separator. */
export const MAX_RECORD_BYTES = 100 * 1024;

/** Compact display form using the UUID's random suffix. */
export function shortSessionId(sessionId: string): string {
  return sessionId.slice(-8);
}

const REQUEST_ID_PATTERN = /^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$/u;
const SESSION_ID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/iu;
const SESSION_NAME_MAX_LENGTH = 128;
const ISO_TIMESTAMP_PATTERN =
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?Z$/u;

export type SessionEndpoint = {
  sessionId: string;
  sessionName?: string;
  cwd: string;
  mode: "tui" | "rpc";
  pid: number;
  state: "idle" | "busy";
  startedAt: string;
  socketPath: string;
};

export type SenderMetadata = {
  sessionId: string;
  sessionName?: string;
};

export type SendRequest = {
  id: string;
  type: "send";
  message: string;
  sender?: SenderMetadata;
};

export type PasteRequest = {
  id: string;
  type: "paste";
  text: string;
};

export type LastMessageRequest = {
  id: string;
  type: "last_message";
};

export type ControlRequest = SendRequest | PasteRequest | LastMessageRequest;

export type ControlError = {
  code: string;
  message: string;
};

export type ControlResponse = {
  id: string;
  type: "response";
  success: boolean;
  data?: unknown;
  error?: ControlError;
};

export type AssistantResult = {
  text: string;
  timestamp: number;
  messageId?: string;
};

export type SendOptions = {
  message: string;
  sender?: SenderMetadata;
};

export type SendResult = {
  accepted: true;
};

export type PasteResult = {
  pasted: true;
};

export type ControlProtocolErrorCode =
  | "invalid_record"
  | "malformed_json"
  | "record_too_large";

export class ControlProtocolError extends Error {
  readonly code: ControlProtocolErrorCode;

  constructor(code: ControlProtocolErrorCode, message: string) {
    super(message);
    this.name = "ControlProtocolError";
    this.code = code;
  }
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function assertObject(
  value: unknown,
  description: string,
): asserts value is Record<string, unknown> {
  if (!isObject(value)) {
    throw new ControlProtocolError(
      "invalid_record",
      `${description} must be an object`,
    );
  }
}

function assertExactFields(
  value: Record<string, unknown>,
  required: readonly string[],
  optional: readonly string[] = [],
): void {
  const allowed = new Set([...required, ...optional]);
  for (const field of required) {
    if (!Object.hasOwn(value, field)) {
      throw new ControlProtocolError(
        "invalid_record",
        `Missing required field: ${field}`,
      );
    }
  }
  for (const field of Object.keys(value)) {
    if (!allowed.has(field)) {
      throw new ControlProtocolError(
        "invalid_record",
        `Unknown field: ${field}`,
      );
    }
  }
}

export function isValidRequestId(value: unknown): value is string {
  return typeof value === "string" && REQUEST_ID_PATTERN.test(value);
}

export function isValidSessionId(value: unknown): value is string {
  return typeof value === "string" && SESSION_ID_PATTERN.test(value);
}

function assertRequestId(value: unknown): asserts value is string {
  if (!isValidRequestId(value)) {
    throw new ControlProtocolError("invalid_record", "Invalid request id");
  }
}

function assertSessionId(value: unknown): asserts value is string {
  if (!isValidSessionId(value)) {
    throw new ControlProtocolError("invalid_record", "Invalid session id");
  }
}

function isValidSessionName(value: unknown): value is string {
  return (
    typeof value === "string" &&
    value === value.trim() &&
    value.length > 0 &&
    value.length <= SESSION_NAME_MAX_LENGTH &&
    !value.includes("\0")
  );
}

function assertSenderMetadata(value: unknown): asserts value is SenderMetadata {
  assertObject(value, "sender");
  assertExactFields(value, ["sessionId"], ["sessionName"]);
  assertSessionId(value.sessionId);
  if (
    value.sessionName !== undefined &&
    !isValidSessionName(value.sessionName)
  ) {
    throw new ControlProtocolError(
      "invalid_record",
      "Invalid sender session name",
    );
  }
}

function assertNonEmptyText(value: unknown, description: string): void {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new ControlProtocolError(
      "invalid_record",
      `${description} must not be empty`,
    );
  }
}

/** Validate an untrusted parsed JSON value as one complete control request. */
export function validateControlRequest(value: unknown): ControlRequest {
  assertObject(value, "Control request");
  assertRequestId(value.id);
  if (typeof value.type !== "string") {
    throw new ControlProtocolError(
      "invalid_record",
      "Request type must be a string",
    );
  }

  switch (value.type) {
    case "last_message":
      assertExactFields(value, ["id", "type"]);
      break;
    case "send":
      assertExactFields(value, ["id", "type", "message"], ["sender"]);
      assertNonEmptyText(value.message, "Send message");
      if (value.sender !== undefined) assertSenderMetadata(value.sender);
      break;
    case "paste":
      assertExactFields(value, ["id", "type", "text"]);
      assertNonEmptyText(value.text, "Paste text");
      break;
    default:
      throw new ControlProtocolError(
        "invalid_record",
        `Unsupported request type: ${value.type}`,
      );
  }

  return value as ControlRequest;
}

function assertControlError(value: unknown): asserts value is ControlError {
  assertObject(value, "Response error");
  assertExactFields(value, ["code", "message"]);
  if (typeof value.code !== "string" || value.code.length === 0) {
    throw new ControlProtocolError(
      "invalid_record",
      "Response error code must not be empty",
    );
  }
  if (typeof value.message !== "string" || value.message.length === 0) {
    throw new ControlProtocolError(
      "invalid_record",
      "Response error message must not be empty",
    );
  }
}

/** Validate an untrusted parsed JSON value as one server response. */
export function validateControlResponse(value: unknown): ControlResponse {
  assertObject(value, "Control response");
  assertRequestId(value.id);
  assertExactFields(value, ["id", "type", "success"], ["data", "error"]);
  if (value.type !== "response") {
    throw new ControlProtocolError(
      "invalid_record",
      "Record type must be response",
    );
  }
  if (typeof value.success !== "boolean") {
    throw new ControlProtocolError(
      "invalid_record",
      "Response success must be boolean",
    );
  }
  if (value.success && value.error !== undefined) {
    throw new ControlProtocolError(
      "invalid_record",
      "Successful response must not contain an error",
    );
  }
  if (!value.success && value.error === undefined) {
    throw new ControlProtocolError(
      "invalid_record",
      "Failed response must contain an error",
    );
  }
  if (value.error !== undefined) assertControlError(value.error);
  return value as ControlResponse;
}

/** Validate endpoint metadata read from the local discovery directory. */
export function validateSessionEndpoint(value: unknown): SessionEndpoint {
  assertObject(value, "Session endpoint");
  assertExactFields(
    value,
    ["sessionId", "cwd", "mode", "pid", "state", "startedAt", "socketPath"],
    ["sessionName"],
  );
  assertSessionId(value.sessionId);
  if (
    value.sessionName !== undefined &&
    !isValidSessionName(value.sessionName)
  ) {
    throw new ControlProtocolError("invalid_record", "Invalid session name");
  }
  if (
    typeof value.cwd !== "string" ||
    !value.cwd.startsWith("/") ||
    value.cwd.includes("\0")
  ) {
    throw new ControlProtocolError(
      "invalid_record",
      "Endpoint cwd must be an absolute path",
    );
  }
  if (value.mode !== "tui" && value.mode !== "rpc") {
    throw new ControlProtocolError(
      "invalid_record",
      "Endpoint mode must be tui or rpc",
    );
  }
  if (!Number.isSafeInteger(value.pid) || (value.pid as number) <= 0) {
    throw new ControlProtocolError(
      "invalid_record",
      "Endpoint pid must be a positive integer",
    );
  }
  if (value.state !== "idle" && value.state !== "busy") {
    throw new ControlProtocolError(
      "invalid_record",
      "Endpoint state must be idle or busy",
    );
  }
  if (
    typeof value.startedAt !== "string" ||
    !ISO_TIMESTAMP_PATTERN.test(value.startedAt) ||
    !Number.isFinite(Date.parse(value.startedAt))
  ) {
    throw new ControlProtocolError(
      "invalid_record",
      "Endpoint startedAt must be an ISO timestamp",
    );
  }
  if (
    typeof value.socketPath !== "string" ||
    !value.socketPath.startsWith("/") ||
    value.socketPath.includes("\0")
  ) {
    throw new ControlProtocolError(
      "invalid_record",
      "Endpoint socketPath must be an absolute path",
    );
  }
  return value as SessionEndpoint;
}

function parseJsonPayload(payload: Buffer): unknown {
  let text: string;
  try {
    text = new TextDecoder("utf-8", { fatal: true }).decode(payload);
  } catch {
    throw new ControlProtocolError(
      "malformed_json",
      "Control record is not valid UTF-8",
    );
  }
  try {
    return JSON.parse(text) as unknown;
  } catch {
    throw new ControlProtocolError(
      "malformed_json",
      "Control record is not valid JSON",
    );
  }
}

/** Incrementally split bounded LF-delimited JSON without partial UTF-8 decoding. */
export class JsonLineDecoder {
  private buffered = Buffer.alloc(0);

  push(chunk: Uint8Array): unknown[] {
    if (chunk.byteLength === 0) return [];
    this.buffered = Buffer.concat([this.buffered, Buffer.from(chunk)]);
    const records: unknown[] = [];

    let newlineIndex = this.buffered.indexOf(0x0a);
    while (newlineIndex !== -1) {
      let payload = this.buffered.subarray(0, newlineIndex);
      this.buffered = this.buffered.subarray(newlineIndex + 1);
      if (payload.at(-1) === 0x0d)
        payload = payload.subarray(0, payload.length - 1);
      this.assertPayloadSize(payload.byteLength);
      if (payload.byteLength === 0) {
        throw new ControlProtocolError(
          "malformed_json",
          "Control record must not be empty",
        );
      }
      records.push(parseJsonPayload(payload));
      newlineIndex = this.buffered.indexOf(0x0a);
    }

    if (this.buffered.byteLength > MAX_RECORD_BYTES + 1) {
      throw new ControlProtocolError(
        "record_too_large",
        "Control record exceeds 102400 bytes",
      );
    }
    return records;
  }

  finish(): void {
    if (this.buffered.byteLength !== 0) {
      throw new ControlProtocolError(
        "malformed_json",
        "Control record is missing its LF separator",
      );
    }
  }

  private assertPayloadSize(size: number): void {
    if (size > MAX_RECORD_BYTES) {
      throw new ControlProtocolError(
        "record_too_large",
        "Control record exceeds 102400 bytes",
      );
    }
  }
}

/** Encode one value as a bounded UTF-8 JSONL record. */
export function encodeJsonLine(value: unknown): Buffer {
  let serialized: string | undefined;
  try {
    serialized = JSON.stringify(value);
  } catch {
    throw new ControlProtocolError(
      "invalid_record",
      "Control record is not JSON serializable",
    );
  }
  if (serialized === undefined) {
    throw new ControlProtocolError(
      "invalid_record",
      "Control record is not JSON serializable",
    );
  }
  const payload = Buffer.from(serialized, "utf8");
  if (payload.byteLength > MAX_RECORD_BYTES) {
    throw new ControlProtocolError(
      "record_too_large",
      "Control record exceeds 102400 bytes",
    );
  }
  return Buffer.concat([payload, Buffer.from("\n")]);
}
