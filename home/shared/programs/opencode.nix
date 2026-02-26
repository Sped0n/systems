{
  config,
  lib,
  pkgs,
  secrets,
  vars,
  ...
}:
let
  opencode = config.programs.opencode;
in
{
  programs = {
    opencode = {
      enable = lib.mkDefault false;
      package = pkgs.llm-agents.opencode;
    };
    zsh.shellAliases = lib.mkIf opencode.enable {
      ocommit = "oc-ephemeral-run --agent commit-message-writer \"STAGED CHANGE ONLY\" 2>/dev/null && git commit -s -e -F \"$(git rev-parse --git-path COMMIT_EDITMSG)\"";
    };
  };

  xdg.configFile = lib.mkIf opencode.enable {
    "opencode/opencode.jsonc".source = (
      config.lib.file.mkOutOfStoreSymlink "${vars.home}/.config/systems/home/raw/opencode/config.jsonc"
    );
    "opencode/AGENTS.md".source = (
      config.lib.file.mkOutOfStoreSymlink "${vars.home}/.config/systems/home/raw/opencode/AGENTS.md"
    );
    "opencode/agents".source = (
      config.lib.file.mkOutOfStoreSymlink "${vars.home}/.config/systems/home/raw/opencode/agents"
    );
    "opencode/skills".source = (
      config.lib.file.mkOutOfStoreSymlink "${vars.home}/.config/systems/home/raw/opencode/skills"
    );
  };

  age.secrets = lib.mkIf opencode.enable {
    "openrouter-api-key" = {
      file = "${secrets}/ages/openrouter-api-key.age";
      mode = "0400";
    };
    "yescode-api-key" = {
      file = "${secrets}/ages/yescode-api-key.age";
      mode = "0400";
    };
    "jina-api-key" = {
      file = "${secrets}/ages/jina-api-key.age";
      mode = "0400";
    };
  };

  home.packages = lib.mkIf opencode.enable [
    (pkgs.writeShellScriptBin "oc" ''
      set -euo pipefail
      export OPENCODE_EXPERIMENTAL_MARKDOWN=1
      export OPENCODE_EXPERIMENTAL_PLAN_MODE=1
      export OPENROUTER_API_KEY="$(${pkgs.coreutils}/bin/cat ${
        config.age.secrets."openrouter-api-key".path
      })"
      export YESCODE_API_KEY="$(${pkgs.coreutils}/bin/cat ${config.age.secrets."yescode-api-key".path})"
      export JINA_API_KEY="$(${pkgs.coreutils}/bin/cat ${config.age.secrets."jina-api-key".path})"
      exec ${lib.getExe opencode.package} "$@"
    '')

    (pkgs.writeShellScriptBin "oc-ephemeral-run" ''
      set -euo pipefail

      usage() {
        ${pkgs.coreutils}/bin/printf "%s\\n" \
          "Usage: oc-ephemeral-run [OC_ARGS...] PROMPT" \
          "" \
          "Runs oc --title <UUID> [OC_ARGS...] run <PROMPT> and deletes the session after completion." \
          "" \
          "Example:" \
          "  oc-ephemeral-run --agent blabla --model hahaha \"hello world\""
      }

      if [ "$#" -lt 1 ]; then
        usage >&2
        exit 2
      fi

      uuid=""

      cleanup() {
        set +e

        if [ -z "$uuid" ]; then
          return
        fi

        session_id="$(
          oc session list --format json 2>/dev/null \
            | ${pkgs.jq}/bin/jq -r --arg title "$uuid" '.[] | select(.title == $title) | .id' 2>/dev/null \
            | ${pkgs.coreutils}/bin/head -n 1
        )"

        if [ -n "$session_id" ]; then
          oc session delete "$session_id" >/dev/null 2>&1 \
            || echo "oc-ephemeral-run: warning: failed to delete session $session_id" >&2
        else
          echo "oc-ephemeral-run: warning: failed to resolve session id for title $uuid" >&2
        fi
      }
      trap cleanup EXIT

      prompt="''${!#}"
      if [ "$#" -gt 1 ]; then
        oc_args=("''${@:1:$#-1}")
      else
        oc_args=()
      fi

      for arg in "''${oc_args[@]}"; do
        case "$arg" in
          --session|--session=*)
            echo "oc-ephemeral-run: do not pass --session; it is generated automatically" >&2
            exit 2
            ;;
          --title|--title=*)
            echo "oc-ephemeral-run: do not pass --title; it is generated automatically" >&2
            exit 2
            ;;
        esac
      done

      if [ -r /proc/sys/kernel/random/uuid ]; then
        uuid="$(${pkgs.coreutils}/bin/cat /proc/sys/kernel/random/uuid)"
      elif [ -x /usr/bin/uuidgen ]; then
        uuid="$(/usr/bin/uuidgen)"
      elif command -v uuidgen >/dev/null 2>&1; then
        uuid="$(uuidgen)"
      else
        echo "oc-ephemeral-run: unable to generate UUID" >&2
        exit 1
      fi

      uuid="$(${pkgs.coreutils}/bin/printf %s "$uuid" | ${pkgs.coreutils}/bin/tr -d '\r\n')"

      oc_status=0
      if oc --title "$uuid" "''${oc_args[@]}" run "$prompt"; then
        oc_status=0
      else
        oc_status=$?
      fi

      exit "$oc_status"
    '')
  ];
}
