#!/usr/bin/env node
import { parseArgs } from "node:util";
import {
    ClientControlError,
    ServerControlError,
    SessionTargetError,
    UnixSessionControlClient,
} from "../extensions/control/client.ts";
import { getSessionControlDirectory } from "../extensions/control/discovery.ts";
import {
    ControlProtocolError,
    MAX_RECORD_BYTES,
    isValidSessionId,
    shortSessionId,
    type RunResult,
    type SenderMetadata,
} from "../extensions/control/protocol.ts";

const HELP = `Usage:
  pontrol list [--cwd PATH] [--json]
  pontrol run SESSION TEXT [--wait] [--for DURATION] [--json]
  pontrol send SESSION TEXT [--draft] [--json]
  pontrol capture SESSION [--lines N] [--json]
  pontrol capture --run RUN [--lines N] [--json]
  pontrol wait RUN [--for DURATION] [--json]

Use --stdin instead of TEXT for multiline input. Use -- before text starting with -.
--timeout limits connections and initial responses. --for limits an acknowledged wait.
A timeout or interrupted wait does not cancel the agent's work.
`;

class UsageError extends Error {}

function duration(value: string | undefined): number | undefined {
    if (value === undefined) return undefined;
    const match = /^(\d+(?:\.\d+)?)(ms|s|m|h)$/u.exec(value);
    if (!match)
        throw new UsageError("Duration must have a unit: ms, s, m, or h");
    const units: Record<string, number> = {
        ms: 1,
        s: 1000,
        m: 60_000,
        h: 3_600_000,
    };
    const milliseconds = Number(match[1]) * units[match[2]];
    if (milliseconds < 1 || milliseconds > 2_147_483_647)
        throw new UsageError("Duration is outside the supported range");
    return milliseconds;
}

async function readInput(): Promise<string> {
    let length = 0;
    const chunks: Buffer[] = [];
    for await (const chunk of process.stdin) {
        const bytes = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
        length += bytes.length;
        if (length > MAX_RECORD_BYTES)
            throw new UsageError("Input exceeds the control record size limit");
        chunks.push(bytes);
    }
    return Buffer.concat(chunks).toString("utf8");
}

function json(value: unknown): void {
    process.stdout.write(JSON.stringify(value) + "\n");
}

async function sender(
    client: UnixSessionControlClient,
): Promise<SenderMetadata | undefined> {
    const sessionId = process.env.PI_SESSION_ID;
    if (!isValidSessionId(sessionId)) return undefined;
    const endpoint = (await client.list()).find(
        (item) => item.sessionId === sessionId,
    );
    return {
        sessionId,
        ...(endpoint?.sessionName ? { sessionName: endpoint.sessionName } : {}),
    };
}

function finish(result: RunResult, asJson: boolean): void {
    if (asJson) json(result);
    if (result.status !== "completed") {
        process.exitCode = 1;
        if (!asJson)
            process.stderr.write(
                `pontrol: run ${result.status}${result.error ? `: ${result.error}` : ""}\n`,
            );
    }
}

async function main(): Promise<void> {
    const parse = () =>
        parseArgs({
            allowPositionals: true,
            options: {
                help: { type: "boolean" },
                json: { type: "boolean" },
                stdin: { type: "boolean" },
                draft: { type: "boolean" },
                wait: { type: "boolean" },
                run: { type: "string" },
                cwd: { type: "string" },
                lines: { type: "string" },
                for: { type: "string" },
                timeout: { type: "string" },
            },
        });
    let parsed: ReturnType<typeof parse>;
    try {
        parsed = parse();
    } catch (error) {
        throw new UsageError(
            error instanceof Error ? error.message : "Invalid arguments",
        );
    }
    const { values, positionals } = parsed;
    if (values.help || positionals.length === 0) {
        process.stdout.write(HELP);
        return;
    }
    const [command, target, text] = positionals;
    const allowed: Record<string, string[]> = {
        list: ["cwd"],
        run: ["stdin", "wait", "for"],
        send: ["stdin", "draft"],
        capture: ["run", "lines"],
        wait: ["for"],
    };
    if (!allowed[command]) throw new UsageError(`Unknown command: ${command}`);
    for (const key of Object.keys(values)) {
        if (!["help", "json", "timeout", ...allowed[command]].includes(key))
            throw new UsageError(`--${key} is not supported by ${command}`);
    }
    if (values.for && command === "run" && !values.wait)
        throw new UsageError("--for requires --wait");
    const timeoutMs = duration(values.timeout);
    const waitTimeoutMs = duration(values.for);
    const client = new UnixSessionControlClient({
        controlDirectory: getSessionControlDirectory(),
        ...(timeoutMs
            ? { connectionTimeoutMs: timeoutMs, responseTimeoutMs: timeoutMs }
            : {}),
    });
    if (command === "list") {
        if (positionals.length !== 1)
            throw new UsageError("list takes no positional arguments");
        const endpoints = (await client.list({ cwd: values.cwd })).filter(
            (item) => item.sessionId !== process.env.PI_SESSION_ID,
        );
        if (values.json) json(endpoints);
        else
            for (const item of endpoints)
                process.stdout.write(
                    `${shortSessionId(item.sessionId)}\t${item.sessionName ?? "-"}\t${item.state}\t${item.cwd}\n`,
                );
        return;
    }
    if (command === "capture") {
        if (values.run ? target !== undefined : target === undefined)
            throw new UsageError("Specify SESSION or --run RUN, not both");
        if (positionals.length > (values.run ? 1 : 2))
            throw new UsageError("Too many capture arguments");
        const lines = values.lines === undefined ? 100 : Number(values.lines);
        if (!Number.isSafeInteger(lines) || lines < 1 || lines > 1000)
            throw new UsageError("--lines must be between 1 and 1000");
        const captured = await client.capture(values.run ?? target!, {
            run: values.run !== undefined,
            lines,
        });
        if (values.json) json(captured);
        else process.stdout.write(captured.text + "\n");
        return;
    }
    if (!target) throw new UsageError(`${command} requires a target`);
    const controller = new AbortController();
    const interrupt = () => controller.abort(new Error("Interrupted"));
    if (command === "wait") process.once("SIGINT", interrupt);
    try {
        if (command === "wait") {
            if (positionals.length !== 2)
                throw new UsageError("wait requires one run handle");
            finish(
                await client.wait(target, {
                    timeoutMs: waitTimeoutMs,
                    signal: controller.signal,
                }),
                values.json === true,
            );
            return;
        }
        if (
            positionals.length > 3 ||
            (values.stdin ? text !== undefined : text === undefined)
        )
            throw new UsageError(
                "Supply one text argument or --stdin, not both",
            );
        const message = values.stdin ? await readInput() : text!;
        if (!message.trim()) throw new UsageError("Message must not be empty");
        const from = await sender(client);
        if (command === "send") {
            const result = await client.send(target, {
                message,
                draft: values.draft === true,
                ...(from ? { sender: from } : {}),
            });
            if (values.json) json(result);
            return;
        }
        if (values.wait) process.once("SIGINT", interrupt);
        const run = await client.run(target, {
            message,
            ...(from ? { sender: from } : {}),
        });
        if (values.json) json(run);
        else process.stdout.write(run.handle + "\n");
        if (values.wait)
            finish(
                await client.wait(run.handle, {
                    timeoutMs: waitTimeoutMs,
                    signal: controller.signal,
                }),
                values.json === true,
            );
    } catch (error) {
        if (controller.signal.aborted) {
            process.exitCode = 130;
            process.stderr.write(
                "pontrol: interrupted; run was not cancelled\n",
            );
            return;
        }
        throw error;
    } finally {
        process.removeListener("SIGINT", interrupt);
    }
}

main().catch((error: unknown) => {
    const code =
        error instanceof UsageError
            ? 2
            : error instanceof SessionTargetError
              ? 3
              : error instanceof ServerControlError
                ? 4
                : error instanceof ControlProtocolError
                  ? 5
                  : error instanceof ClientControlError
                    ? error.code === "timeout"
                        ? 124
                        : error.code === "protocol_error"
                          ? 5
                          : 3
                    : 1;
    const message = error instanceof Error ? error.message : String(error);
    if (process.argv.includes("--json"))
        json({
            error: {
                code:
                    error instanceof ClientControlError ||
                    error instanceof ServerControlError ||
                    error instanceof SessionTargetError
                        ? error.code
                        : "error",
                message,
            },
        });
    else process.stderr.write(`pontrol: ${message}\n`);
    process.exitCode = code;
});
