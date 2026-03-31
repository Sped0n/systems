{
  config,
  lib,
  pkgs,
  secrets,
  ...
}:
let
  opencode = config.programs.opencode;
in
{
  age.secrets = lib.mkIf opencode.enable {
    "newapi-api-key" = {
      file = "${secrets}/ages/newapi-api-key.age";
      mode = "0400";
    };
  };

  home.packages = lib.mkIf opencode.enable [
    (pkgs.writeShellScriptBin "oc" ''
      set -euo pipefail
      export OPENCODE_EXPERIMENTAL_MARKDOWN=1
      export OPENCODE_EXPERIMENTAL_PLAN_MODE=1
      export NEWAPI_API_KEY="$(${pkgs.coreutils}/bin/cat ${config.age.secrets."newapi-api-key".path})"
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

    (pkgs.writeShellScriptBin "ocommit" ''
      exec ${lib.getExe pkgs.python3} "${./ocommit.py}" "$@"
    '')
  ];
}
