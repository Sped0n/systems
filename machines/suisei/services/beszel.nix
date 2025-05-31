{
  pkgs,
  vars,
  ...
}: {
  systemd.services.beszel-agent = {
    enable = true;
    description = "Beszel Agent";
    after = ["network.target" "tailscaled.service"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];
    environment = {
      LISTEN = "45876";
      KEY = vars.beszelAgentKey;
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
