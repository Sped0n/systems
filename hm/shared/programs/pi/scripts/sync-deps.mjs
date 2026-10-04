import { execFileSync } from "node:child_process";
import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptsDirectory = path.dirname(fileURLToPath(import.meta.url));
const piDirectory = path.resolve(scriptsDirectory, "..");
const repositoryDirectory = path.resolve(piDirectory, "../../../..");
const runtimeDirectory = path.join(piDirectory, "runtime");
const packagePath = path.join(piDirectory, "package.json");

const piVersion = execFileSync(
    "nix",
    [
        "eval",
        "--raw",
        "--impure",
        "--no-write-lock-file",
        "--expr",
        '(builtins.getFlake ("path:" + builtins.getEnv "PI_SYNC_FLAKE")).inputs.llm-agents.packages.${builtins.currentSystem}.pi.version',
    ],
    {
        cwd: repositoryDirectory,
        env: { ...process.env, PI_SYNC_FLAKE: repositoryDirectory },
        encoding: "utf8",
        stdio: ["ignore", "pipe", "inherit"],
    },
).trim();

const runtimePackage = JSON.parse(
    await readFile(path.join(runtimeDirectory, "package.json"), "utf8"),
);
const packageJson = JSON.parse(await readFile(packagePath, "utf8"));
const dependencies = {
    ...packageJson.dependencies,
    ...runtimePackage.dependencies,
    "@earendil-works/pi-ai": piVersion,
    "@earendil-works/pi-coding-agent": piVersion,
    "@earendil-works/pi-tui": piVersion,
};
if (
    Object.entries(dependencies).some(
        ([name, version]) => packageJson.dependencies[name] !== version,
    )
) {
    packageJson.dependencies = dependencies;
    await writeFile(packagePath, `${JSON.stringify(packageJson, null, 2)}\n`);
}

console.log(`Synchronizing dependencies with Nix Pi ${piVersion}`);
execFileSync(
    "npm",
    [
        "install",
        "--package-lock-only",
        "--ignore-scripts",
        "--no-audit",
        "--no-fund",
    ],
    { cwd: runtimeDirectory, stdio: "inherit" },
);
execFileSync("pnpm", ["install", "--no-frozen-lockfile"], {
    cwd: piDirectory,
    stdio: "inherit",
});
