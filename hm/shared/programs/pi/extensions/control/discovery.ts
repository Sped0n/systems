import { randomBytes } from "node:crypto";
import { promises as fs } from "node:fs";
import * as net from "node:net";
import * as path from "node:path";

import {
  isValidSessionId,
  validateSessionEndpoint,
  type SessionEndpoint,
} from "./protocol.ts";

const METADATA_SUFFIX = ".json";
const SOCKET_SUFFIX = ".sock";
const DEFAULT_PROBE_TIMEOUT_MS = 300;

export type EndpointProbe = (socketPath: string) => Promise<boolean>;

export type ListSessionEndpointsOptions = {
  cwd?: string;
  probe?: EndpointProbe;
};

export class SessionTargetError extends Error {
  readonly code: "target_missing" | "target_ambiguous";
  readonly matches: readonly SessionEndpoint[];

  constructor(
    code: "target_missing" | "target_ambiguous",
    message: string,
    matches: readonly SessionEndpoint[],
  ) {
    super(message);
    this.name = "SessionTargetError";
    this.code = code;
    this.matches = matches;
  }
}

export function getSessionControlDirectory(agentDirectory?: string): string {
  const configured = agentDirectory ?? process.env.PI_CODING_AGENT_DIR;
  if (!configured) {
    throw new Error(
      "PI_CODING_AGENT_DIR is required for session control discovery",
    );
  }
  return path.join(configured, "session-control");
}

export function getSessionEndpointPaths(
  controlDirectory: string,
  sessionId: string,
): { metadataPath: string; socketPath: string } {
  if (!isValidSessionId(sessionId))
    throw new Error("Invalid session id for endpoint path");
  return {
    metadataPath: path.join(controlDirectory, `${sessionId}${METADATA_SUFFIX}`),
    socketPath: path.join(controlDirectory, `${sessionId}${SOCKET_SUFFIX}`),
  };
}

export async function ensureSessionControlDirectory(
  controlDirectory: string,
): Promise<void> {
  await fs.mkdir(controlDirectory, { recursive: true, mode: 0o700 });
  await fs.chmod(controlDirectory, 0o700);
}

/** Publish validated endpoint metadata with an owner-only atomic rename. */
export async function publishSessionEndpoint(
  controlDirectory: string,
  endpointValue: SessionEndpoint,
): Promise<void> {
  const endpoint = validateSessionEndpoint(endpointValue);
  const paths = getSessionEndpointPaths(controlDirectory, endpoint.sessionId);
  if (endpoint.socketPath !== paths.socketPath) {
    throw new Error(
      "Endpoint socketPath does not match its session control path",
    );
  }
  await ensureSessionControlDirectory(controlDirectory);

  const temporaryPath = `${paths.metadataPath}.tmp-${process.pid}-${randomBytes(6).toString("hex")}`;
  try {
    await fs.writeFile(temporaryPath, `${JSON.stringify(endpoint)}\n`, {
      encoding: "utf8",
      mode: 0o600,
      flag: "wx",
    });
    await fs.chmod(temporaryPath, 0o600);
    await fs.rename(temporaryPath, paths.metadataPath);
  } catch (error) {
    await fs.rm(temporaryPath, { force: true });
    throw error;
  }
}

export async function setSessionSocketPermissions(
  socketPath: string,
): Promise<void> {
  await fs.chmod(socketPath, 0o600);
}

export async function probeSessionSocket(
  socketPath: string,
  timeoutMs = DEFAULT_PROBE_TIMEOUT_MS,
): Promise<boolean> {
  return await new Promise<boolean>((resolve) => {
    const socket = net.createConnection(socketPath);
    let completed = false;
    const finish = (reachable: boolean) => {
      if (completed) return;
      completed = true;
      socket.destroy();
      resolve(reachable);
    };
    socket.setTimeout(timeoutMs, () => finish(false));
    socket.once("connect", () => finish(true));
    socket.once("error", () => finish(false));
  });
}

function metadataSessionId(fileName: string): string | undefined {
  if (!fileName.endsWith(METADATA_SUFFIX)) return undefined;
  const sessionId = fileName.slice(0, -METADATA_SUFFIX.length);
  return isValidSessionId(sessionId) ? sessionId : undefined;
}

async function readEndpointMetadata(
  controlDirectory: string,
  fileName: string,
): Promise<SessionEndpoint | undefined> {
  const sessionId = metadataSessionId(fileName);
  if (!sessionId) return undefined;
  try {
    const parsed: unknown = JSON.parse(
      await fs.readFile(path.join(controlDirectory, fileName), "utf8"),
    );
    const endpoint = validateSessionEndpoint(parsed);
    const expectedPaths = getSessionEndpointPaths(controlDirectory, sessionId);
    if (
      endpoint.sessionId !== sessionId ||
      endpoint.socketPath !== expectedPaths.socketPath
    ) {
      return undefined;
    }
    return endpoint;
  } catch {
    return undefined;
  }
}

/**
 * Remove only a UUID-named metadata/socket pair after its derived socket is unreachable.
 * Paths embedded in metadata are never used for cleanup.
 */
export async function cleanupStaleSessionEndpoint(
  controlDirectory: string,
  sessionId: string,
  probe: EndpointProbe = probeSessionSocket,
): Promise<boolean> {
  if (!isValidSessionId(sessionId)) return false;
  const paths = getSessionEndpointPaths(controlDirectory, sessionId);
  if (await probe(paths.socketPath)) return false;
  await Promise.all([
    fs.rm(paths.metadataPath, { force: true }),
    fs.rm(paths.socketPath, { force: true }),
  ]);
  return true;
}

export async function removeSessionEndpoint(
  controlDirectory: string,
  sessionId: string,
): Promise<void> {
  const paths = getSessionEndpointPaths(controlDirectory, sessionId);
  await Promise.all([
    fs.rm(paths.metadataPath, { force: true }),
    fs.rm(paths.socketPath, { force: true }),
  ]);
}

async function canonicalPath(value: string): Promise<string | undefined> {
  try {
    return await fs.realpath(value);
  } catch {
    return undefined;
  }
}

/** List only strictly validated metadata whose expected Unix socket accepts a connection. */
export async function listSessionEndpoints(
  controlDirectory: string,
  options: ListSessionEndpointsOptions = {},
): Promise<SessionEndpoint[]> {
  await ensureSessionControlDirectory(controlDirectory);
  const probe = options.probe ?? probeSessionSocket;
  const requestedCwd =
    options.cwd === undefined ? undefined : await canonicalPath(options.cwd);
  if (options.cwd !== undefined && requestedCwd === undefined) return [];

  const entries = await fs.readdir(controlDirectory, { withFileTypes: true });
  const endpoints: SessionEndpoint[] = [];
  for (const entry of entries) {
    if (!entry.isFile()) continue;
    const sessionId = metadataSessionId(entry.name);
    if (!sessionId) continue;
    const endpoint = await readEndpointMetadata(controlDirectory, entry.name);
    const socketPath = getSessionEndpointPaths(
      controlDirectory,
      sessionId,
    ).socketPath;
    if (!endpoint) {
      await cleanupStaleSessionEndpoint(controlDirectory, sessionId, probe);
      continue;
    }
    if (!(await probe(socketPath))) {
      await cleanupStaleSessionEndpoint(controlDirectory, sessionId, probe);
      continue;
    }
    if (
      requestedCwd !== undefined &&
      (await canonicalPath(endpoint.cwd)) !== requestedCwd
    )
      continue;
    endpoints.push(endpoint);
  }

  return endpoints.sort((left, right) => {
    const byName = (left.sessionName ?? "").localeCompare(
      right.sessionName ?? "",
    );
    return byName || left.sessionId.localeCompare(right.sessionId);
  });
}

export function resolveSessionTarget(
  endpoints: readonly SessionEndpoint[],
  target: string,
): SessionEndpoint {
  const exactId = endpoints.find((endpoint) => endpoint.sessionId === target);
  if (exactId) return exactId;

  const matchingNames = endpoints.filter(
    (endpoint) => endpoint.sessionName === target,
  );
  if (matchingNames.length === 1) return matchingNames[0];
  if (matchingNames.length > 1) {
    throw new SessionTargetError(
      "target_ambiguous",
      `Session target is ambiguous: ${formatEndpointMatches(matchingNames)}`,
      matchingNames,
    );
  }
  throw new SessionTargetError(
    "target_missing",
    `Session target not found: ${target}`,
    [],
  );
}

function formatEndpointMatches(endpoints: readonly SessionEndpoint[]): string {
  return endpoints
    .map(
      (endpoint) =>
        `${endpoint.sessionName ?? "(unnamed)"} ${endpoint.sessionId} ${endpoint.cwd}`,
    )
    .join(", ");
}
