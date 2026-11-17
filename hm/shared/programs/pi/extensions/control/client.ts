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
    makeRunHandle,
    parseRunHandle,
    type CaptureResult,
    type RunResult,
    type ControlRequest,
    type ControlResponse,
    type SendOptions,
    type SendResult,
    type SessionEndpoint,
} from "./protocol.ts";

const DEFAULT_CONNECTION_TIMEOUT_MS = 1_000;
const DEFAULT_RESPONSE_TIMEOUT_MS = 5_000;

export interface SessionControlClient {
    list(options?: { cwd?: string }): Promise<SessionEndpoint[]>;
    send(target: string, options: SendOptions): Promise<SendResult>;
    run(target: string, options: SendOptions): Promise<RunResult>;
    capture(
        target: string,
        options?: { run?: boolean; lines?: number },
    ): Promise<CaptureResult>;
    wait(
        handle: string,
        options?: { timeoutMs?: number; signal?: AbortSignal },
    ): Promise<RunResult>;
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

    constructor(
        code: ClientControlErrorCode,
        message: string,
        cause?: unknown,
    ) {
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

function requireRunResult(value: unknown): RunResult {
    const data = requireObject(value, "Run result");
    parseRunHandle(data.handle);
    if (
        !["starting", "running", "completed", "failed", "aborted"].includes(
            String(data.status),
        ) ||
        typeof data.startedAt !== "string" ||
        !Number.isFinite(Date.parse(data.startedAt)) ||
        (data.finishedAt !== undefined &&
            (typeof data.finishedAt !== "string" ||
                !Number.isFinite(Date.parse(data.finishedAt)))) ||
        (data.error !== undefined && typeof data.error !== "string")
    )
        throw new ClientControlError("protocol_error", "Invalid run result");
    const terminal = ["completed", "failed", "aborted"].includes(
        String(data.status),
    );
    if (terminal !== (data.finishedAt !== undefined))
        throw new ClientControlError(
            "protocol_error",
            "Inconsistent run completion",
        );
    return data as RunResult;
}

function responseData(response: ControlResponse): unknown {
    if (!response.success) {
        if (!response.error) {
            throw new ClientControlError(
                "protocol_error",
                "Failed response has no error",
            );
        }
        throw new ServerControlError(
            response.error.code,
            response.error.message,
        );
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
            ...options,
        });
        const data = requireObject(responseData(response), "Send response");
        if (data.accepted !== true || data.draft !== (options.draft === true))
            throw new ClientControlError(
                "protocol_error",
                "Invalid send response",
            );
        return { accepted: true, draft: data.draft };
    }

    async run(target: string, options: SendOptions): Promise<RunResult> {
        const endpoint = resolveSessionTarget(await this.list(), target);
        const id = requestId();
        const handle = makeRunHandle(
            endpoint.sessionId,
            endpoint.instanceId,
            id,
        );
        try {
            const request: ControlRequest = {
                id,
                type: "run",
                message: options.message,
                ...(options.sender ? { sender: options.sender } : {}),
            };
            validateControlRequest(request);
            const result = requireRunResult(
                responseData(await this.exchange(endpoint, request)),
            );
            if (result.handle !== handle)
                throw new ClientControlError(
                    "protocol_error",
                    "Mismatched run handle",
                );
            return result;
        } catch (error) {
            if (error instanceof ClientControlError)
                error.message += `; submission may have started. Recover with pontrol capture --run ${handle}`;
            throw error;
        }
    }

    async capture(
        target: string,
        options: { run?: boolean; lines?: number } = {},
    ): Promise<CaptureResult> {
        const response = await this.request(
            options.run ? parseRunHandle(target).sessionId : target,
            {
                id: requestId(),
                type: "capture",
                lines: options.lines ?? 100,
                ...(options.run ? { run: target } : {}),
            },
        );
        const data = requireObject(responseData(response), "Capture response");
        requireString(data.sessionId, "Capture session ID");
        requireString(data.capturedAt, "Capture timestamp");
        requireString(data.text, "Capture text");
        if (
            !["busy", "idle"].includes(String(data.state)) ||
            typeof data.truncated !== "boolean"
        )
            throw new ClientControlError(
                "protocol_error",
                "Invalid capture response",
            );
        if (data.run !== undefined) requireRunResult(data.run);
        if (options.run && (!isObject(data.run) || data.run.handle !== target))
            throw new ClientControlError(
                "protocol_error",
                "Mismatched captured run",
            );
        return data as CaptureResult;
    }

    async wait(
        handle: string,
        options: { timeoutMs?: number; signal?: AbortSignal } = {},
    ): Promise<RunResult> {
        const response = await this.request(
            parseRunHandle(handle).sessionId,
            { id: requestId(), type: "wait", run: handle },
            options,
        );
        const result = requireRunResult(responseData(response));
        if (result.handle !== handle || result.finishedAt === undefined)
            throw new ClientControlError(
                "protocol_error",
                "Invalid wait result",
            );
        return result;
    }

    private async request(
        target: string,
        request: ControlRequest,
        options: { timeoutMs?: number; signal?: AbortSignal } = {},
    ): Promise<ControlResponse> {
        const endpoints = await this.list();
        const endpoint = resolveSessionTarget(endpoints, target);
        try {
            validateControlRequest(request);
        } catch (error) {
            if (error instanceof ControlProtocolError)
                throw mapProtocolError(error);
            throw error;
        }
        return await this.exchange(endpoint, request, options);
    }

    private async exchange(
        endpoint: SessionEndpoint,
        request: ControlRequest,
        options: { timeoutMs?: number; signal?: AbortSignal } = {},
    ): Promise<ControlResponse> {
        return await new Promise<ControlResponse>((resolve, reject) => {
            const socket = net.createConnection(endpoint.socketPath);
            const decoder = new JsonLineDecoder();
            let completed = false;
            let connected = false;
            let accepted = false;
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
                options.signal?.removeEventListener("abort", abort);
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

            const abort = () =>
                fail(options.signal?.reason ?? new Error("Interrupted"));
            options.signal?.addEventListener("abort", abort, { once: true });
            if (options.signal?.aborted) {
                abort();
                return;
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
                        if (isObject(value) && value.type === "accepted") {
                            if (
                                request.type !== "wait" ||
                                accepted ||
                                value.id !== request.id ||
                                Object.keys(value).length !== 2
                            )
                                throw new ClientControlError(
                                    "protocol_error",
                                    "Invalid wait acknowledgement",
                                );
                            accepted = true;
                            clearTimeout(responseTimer);
                            if (options.timeoutMs !== undefined)
                                responseTimer = setTimeout(
                                    () =>
                                        fail(
                                            new ClientControlError(
                                                "timeout",
                                                "Wait deadline expired; run continues",
                                            ),
                                        ),
                                    options.timeoutMs,
                                );
                            continue;
                        }
                        const response = validateControlResponse(value);
                        if (
                            request.type === "wait" &&
                            response.success &&
                            !accepted
                        )
                            throw new ClientControlError(
                                "protocol_error",
                                "Wait result arrived without acknowledgement",
                            );
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
