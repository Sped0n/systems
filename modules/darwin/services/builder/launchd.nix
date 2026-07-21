{ config, lib, pkgs, ... }:
let
  cfg = config.services.my-linux-builder;
  common = import ./lib.nix { inherit config lib pkgs; };
  inherit (common)
    builder
    containerBin
    launchAgentsDir
    mkPlist
    runtimeLabel
    ;

  runtimeScript = pkgs.writeShellScript "my-linux-builder-runtime" ''
    set -euo pipefail

    expected_install_root=${lib.escapeShellArg "${pkgs.apple-container}/"}
    if system_status="$(${containerBin} system status --format json 2>/dev/null)"; then
      install_root="$(printf '%s' "$system_status" | ${lib.getExe pkgs.jq} -er '.installRoot')"
      if [ "$install_root" != "$expected_install_root" ]; then
        ${containerBin} system stop
      fi
    fi

    if ! ${containerBin} system status >/dev/null 2>&1; then
      ${containerBin} system start \
        --install-root ${lib.escapeShellArg pkgs.apple-container} \
        --disable-kernel-install
    fi
  '';

  runtimePlist = mkPlist runtimeLabel {
    Label = runtimeLabel;
    ProgramArguments = [ (toString runtimeScript) ];
    LimitLoadToSessionType = [ "Background" ];
    RunAtLoad = true;
    KeepAlive.SuccessfulExit = false;
  };

  builderScript = pkgs.writeShellScript "run-${builder.name}" ''
      set -euo pipefail

      name=${lib.escapeShellArg builder.name}
      port=${toString builder.port}

      for attempt in $(seq 1 30); do
        if ${containerBin} system status >/dev/null 2>&1; then
          break
        fi
        if [ "$attempt" -eq 30 ]; then
          exit 0
        fi
        sleep 1
      done

      ${lib.optionalString cfg.ephemeral ''
        ${containerBin} stop "$name" 2>/dev/null || true
        ${containerBin} rm "$name" 2>/dev/null || true
      ''}

      if ${lib.boolToString (!cfg.ephemeral)} && ${containerBin} ls --all --quiet 2>/dev/null | /usr/bin/grep -Fx -- "$name" >/dev/null 2>&1; then
        ${containerBin} start "$name" &
      else
        ${lib.escapeShellArgs ([
          containerBin
          "run"
          "--name"
          builder.name
        ] ++ builder.runArgs ++ [
          "--publish"
          "${toString builder.port}:22"
          "--cpus"
          (toString cfg.cores)
          "--memory"
          cfg.memory
          cfg.image
        ])} &
      fi
      container_pid=$!
      stopped_for_idle=0

      ${lib.optionalString (cfg.idleTimeout != null) ''
        idle_seconds=0
        check_interval=60
        while kill -0 "$container_pid" 2>/dev/null; do
          if /usr/sbin/lsof -nP -iTCP:"$port" -sTCP:ESTABLISHED >/dev/null 2>&1; then
            idle_seconds=0
          else
            idle_seconds=$((idle_seconds + check_interval))
            if [ "$idle_seconds" -ge ${toString cfg.idleTimeout} ]; then
              ${containerBin} stop "$name" 2>/dev/null || true
              ${containerBin} rm "$name" 2>/dev/null || true
              stopped_for_idle=1
              break
            fi
          fi
          sleep "$check_interval"
        done
      ''}

      set +e
      wait "$container_pid"
      status=$?
      set -e
      if [ "$stopped_for_idle" -eq 1 ]; then
        exit 0
      fi
      exit "$status"
  '';

  builderPlist =
    let
      label = "dev.apple.container.${builder.name}";
    in
    {
      inherit label;
      path = "${launchAgentsDir}/${label}.plist";
      plist = mkPlist label {
        Label = label;
        ProgramArguments = [ (toString builderScript) ];
        LimitLoadToSessionType = [ "Background" ];
        RunAtLoad = false;
        KeepAlive.OtherJobEnabled."com.apple.container.apiserver" = true;
      };
    };
in
{
  config._module.args.myLinuxBuilderLaunchd = {
    inherit builderPlist runtimePlist runtimeScript;
  };
}
