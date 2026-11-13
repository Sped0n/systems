{
  config,
  lib,
  pkgs,
  ...
}:
let
  toml = pkgs.formats.toml { };
in
{
  options.programs.lcs.enable = lib.mkEnableOption "LCS local cache client and user service";

  config = lib.mkIf config.programs.lcs.enable {
    assertions = [
      {
        assertion =
          config.xdg.stateHome == "${config.home.homeDirectory}/.local/state"
          && config.xdg.cacheHome == "${config.home.homeDirectory}/.cache";
        message = "LCS's systemd-managed directories require the default XDG state and cache paths.";
      }
    ];

    home.packages = [ pkgs.lcs ];

    xdg.configFile."lcs/config.toml".source = toml.generate "lcs-config.toml" {
      cache_size = "50GB";
      cache = [
        "git:https://github.com/project-chip/connectedhomeip.git"
        "git:https://github.com/espressif/connectedhomeip.git"

        # Shared ESP32 and Linux dependencies.
        "git:https://pigweed.googlesource.com/pigweed/pigweed.git"
        "git:https://github.com/openthread/openthread.git"
        "git:https://github.com/mackron/miniaudio"

        # Linux dependencies.
        "git:https://github.com/Mbed-TLS/mbedtls.git"
        "git:https://github.com/google/boringssl.git"
        "git:https://github.com/google/perfetto.git"
        "git:https://github.com/ocornut/imgui"
        "git:https://github.com/warmcat/libwebsockets"
        "git:https://github.com/paullouisageneau/libdatachannel.git"

        # ESP32 WebRTC SDK.
        "git:https://github.com/awslabs/amazon-kinesis-video-streams-webrtc-sdk-c"

        # Nested dependencies.
        "git:https://github.com/Mbed-TLS/mbedtls-framework"
        "git:https://github.com/nlohmann/json.git"
        "git:https://github.com/awslabs/amazon-kinesis-video-streams-producer-c.git"
      ];
    };

    # Prevent systemd from treating the config directory as legacy state.
    home.activation.prepareLcsDirectories =
      lib.hm.dag.entryBetween [ "reloadSystemd" ] [ "writeBoundary" ]
        ''
          run ${pkgs.coreutils}/bin/install -d -m 0700 -- \
            ${lib.escapeShellArg "${config.xdg.stateHome}/lcs"} \
            ${lib.escapeShellArg "${config.xdg.cacheHome}/lcs"}
        '';

    systemd.user.services.lcs = {
      Unit = {
        Description = "LCS Local Cache Server";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };

      Service = {
        Type = "simple";
        ExecStart = "${lib.getExe pkgs.lcs} serve --config \"${config.xdg.configHome}/lcs/config.toml\"";
        Restart = "on-failure";
        RestartSec = 3;
        UMask = "0077";
        StateDirectory = "lcs";
        CacheDirectory = "lcs";
        StateDirectoryMode = "0700";
        CacheDirectoryMode = "0700";
      };

      Install.WantedBy = [ "default.target" ];
    };
  };
}
