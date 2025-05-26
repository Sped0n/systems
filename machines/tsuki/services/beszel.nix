{
  pkgs,
  vars,
  home,
  username,
  ...
}: {
  systemd.tmpfiles.rules = [
    "d ${home}/infra 0755 ${username} users -"
    "d ${home}/infra/data 0755 ${username} users -"
    "d ${home}/infra/data/beszel 0755 ${username} users -"
  ];

  systemd.services.beszel-hub = {
    enable = true;
    description = "Beszel Hub";
    after = ["network.target" "tailscaled.service"];
    wantedBy = ["multi-user.target"];
    environment = {
      DISABLE_PASSWORD_AUTH = "true"; # use oidc instead
    };
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "3s";
      User = "${username}";
      WorkingDirectory = "${home}/infra/data/beszel";
      ExecStart = ''
        ${pkgs.beszel}/bin/beszel-hub serve --http "0.0.0.0:8090"
      '';
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  systemd.services.beszel-agent = {
    enable = true;
    description = "Beszel Agent";
    after = ["network.target" "tailscaled.service"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];
    environment = {
      LISTEN = "45876";
      KEY = vars.tsuki.beszelAgentKey;
    };
    serviceConfig = {
      ExecStart = "${pkgs.beszel}/bin/beszel-agent";
      Restart = "on-failure";
      RestartSec = "5s";
      StateDirectory = "beszel-agent";

      # Security/Sandboxing Settings
      KeyringMode = "private";
      LockPersonality = true;
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectClock = true;
      ProtectHome = "read-only";
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectSystem = "strict";
      RemoveIPC = true;
      RestrictSUIDSGID = true;
      SystemCallArchitectures = "native";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };
}
