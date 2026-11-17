{
  config,
  configDir,
  lib,
  pkgs,
}:
let
  cfg = config.programs.my-pi;
  pommitModelFlags = lib.escapeShellArgs [
    "--provider"
    cfg.pommit.provider
    "--model"
    cfg.pommit.model
    "--thinking"
    cfg.pommit.thinking
  ];
  runtimeEnvironment = ''
    export CIRCE_API_KEY="$(${pkgs.coreutils}/bin/cat ${config.age.secrets."circe-api-key".path})"
    export JINA_API_KEY="$(${pkgs.coreutils}/bin/cat ${config.age.secrets."jina-api-key".path})"
    export JINA_API_BASE="https://jina.sped0n.com/api"
    export JINA_READER_BASE="https://jina.sped0n.com/r"
    export JINA_SEARCH_SVIP_BASE="https://jina.sped0n.com/svip"
    export PI_CODING_AGENT_DIR="${configDir}"
    export PI_CONFIG_NODE_MODULES="${
      pkgs.importNpmLock.buildNodeModules {
        npmRoot = ./runtime;
        nodejs = pkgs.nodejs;
        derivationArgs.dontNpmRebuild = true;
      }
    }/node_modules"
    export NO_COLOR=1
    export PATH="$PATH:${
      lib.makeBinPath [
        pkgs.python3
        pkgs.fd
        pkgs.ripgrep
      ]
    }"
  '';
in
[
  (lib.hiPrio (
    pkgs.writeShellScriptBin "pi" ''
      set -euo pipefail
      ${runtimeEnvironment}
      exec ${lib.getExe pkgs.llm-agents.pi} "$@"
    ''
  ))
]
++ lib.optional cfg.pontrol.enable (
  pkgs.writeShellScriptBin "pontrol" ''
    set -euo pipefail
    export PI_CODING_AGENT_DIR="${configDir}"
    exec ${lib.getExe pkgs.nodejs} ${
      pkgs.runCommand "pontrol.mjs" { nativeBuildInputs = [ pkgs.esbuild ]; } ''
        mkdir -p source/scripts source/extensions/control
        cp ${./scripts/pontrol.ts} source/scripts/pontrol.ts
        cp ${./extensions/control/client.ts} source/extensions/control/client.ts
        cp ${./extensions/control/discovery.ts} source/extensions/control/discovery.ts
        cp ${./extensions/control/protocol.ts} source/extensions/control/protocol.ts
        esbuild source/scripts/pontrol.ts \
          --bundle \
          --platform=node \
          --format=esm \
          --outfile=$out
      ''
    } "$@"
  ''
)
++ lib.optional cfg.pommit.enable (
  pkgs.writeShellScriptBin "pommit" ''
    set -euo pipefail
    ${runtimeEnvironment}
    message_file="$(${pkgs.coreutils}/bin/mktemp -t pommit-message.XXXXXX)"
    trap '${pkgs.coreutils}/bin/rm -f "$message_file"' EXIT
    # Pi's custom boolean flag parser consumes a following positional value,
    # so the print-mode prompt must precede --pommit.
    if [ "$#" -gt 0 ]; then
      message="$(${lib.getExe pkgs.llm-agents.pi} ${pommitModelFlags} --no-session --print \
        "Inspect the staged changes and generate their Git commit message." \
        --pommit --pommit-hint "$*")"
    else
      message="$(${lib.getExe pkgs.llm-agents.pi} ${pommitModelFlags} --no-session --print \
        "Inspect the staged changes and generate their Git commit message." --pommit)"
    fi
    if [ -z "$message" ]; then
      echo "pommit: the agent returned an empty commit message" >&2
      exit 1
    fi
    printf '%s\n' "$message" > "$message_file"
    printf '%s\n' "$message"
    ${lib.getExe pkgs.git} commit --signoff --edit --file "$message_file"
  ''
)
