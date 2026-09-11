import { readFile } from "node:fs/promises";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const scriptsDirectory = path.dirname(fileURLToPath(import.meta.url));
const piDirectory = path.resolve(scriptsDirectory, "..");
const runtimeDirectory = path.join(piDirectory, "runtime");
const runtimePackagePath = path.join(runtimeDirectory, "package.json");

async function readRuntimeDependencies() {
  const packageJson = JSON.parse(await readFile(runtimePackagePath, "utf8"));
  const dependencies = packageJson.dependencies;
  if (
    !dependencies ||
    typeof dependencies !== "object" ||
    Array.isArray(dependencies)
  ) {
    throw new Error(
      "pi-runtime package.json must contain a dependencies object",
    );
  }
  return dependencies;
}

function run(command, args) {
  execFileSync(command, args, {
    cwd: piDirectory,
    stdio: "inherit",
  });
}

const dependencyNames = Object.keys(await readRuntimeDependencies()).sort();
if (dependencyNames.length === 0) {
  throw new Error("pi-runtime has no dependencies to update");
}

run("npm", [
  "--prefix",
  runtimeDirectory,
  "install",
  "--save-exact",
  ...dependencyNames.map((name) => `${name}@latest`),
]);

const updatedDependencies = await readRuntimeDependencies();
run("pnpm", [
  "add",
  "--save-exact",
  ...Object.entries(updatedDependencies)
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([name, version]) => `${name}@${version}`),
]);
