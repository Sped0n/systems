"""Check CI cache lists against shared Nix settings without evaluating the flake."""

import json
import subprocess
from pathlib import Path

import yaml


def check_cache_sync(repository: Path) -> list[str]:
    expression = """
        let
          config = import ./modules/shared/nix/settings.nix {
            nixpkgs = null;
            nixpkgs-unstable = null;
            vars.username = "cache-check";
          };
        in {
          inherit (config.nix.settings) substituters trusted-public-keys;
        }
    """
    result = subprocess.run(
        ["nix", "eval", "--impure", "--json", "--expr", expression],
        cwd=repository,
        check=True,
        stdout=subprocess.PIPE,
        text=True,
        timeout=30,
    )
    expected = json.loads(result.stdout)
    errors = []
    setup_steps = 0
    for workflow_path in sorted((repository / ".github/workflows").glob("*.y*ml")):
        workflow = yaml.safe_load(workflow_path.read_text(encoding="utf-8"))
        for job_name, job in workflow["jobs"].items():
            for step in job.get("steps", []):
                if not step.get("uses", "").startswith("cachix/install-nix-action@"):
                    continue
                setup_steps += 1
                config = step.get("with", {}).get("extra_nix_config", "")
                actual = {}
                for line in config.splitlines():
                    name, separator, value = line.partition("#")[0].partition("=")
                    if separator:
                        actual[name.strip()] = value.split()
                for name, values in expected.items():
                    if actual.get(name) != values:
                        location = workflow_path.relative_to(repository)
                        errors.append(
                            f"{location} ({job_name}): {name} differs from shared Nix settings\n"
                            f"  expected: {name} = {' '.join(values)}\n"
                            f"  actual:   {name} = {' '.join(actual.get(name, []))}"
                        )
    if not setup_steps:
        errors.append("No cachix/install-nix-action setup steps found in CI workflows")
    return errors


if __name__ == "__main__":
    errors = check_cache_sync(Path(__file__).resolve().parents[2])
    if errors:
        raise SystemExit("\n".join(errors))
    print("CI cache URLs, priorities, and public keys match shared Nix settings.")
