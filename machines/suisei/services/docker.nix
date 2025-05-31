{pkgs, ...}: let
in {
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
  };

  environment.systemPackages = [
    pkgs.docuum
  ];

  systemd = {
    services."docuum" = {
      description = "Docuum: LRU eviction of Docker images";
      wants = ["docker.service"];
      after = ["docker.service"];
      wantedBy = ["multi-user.target"];
      path = with pkgs; [docker];
      serviceConfig = {
        User = "root";
        ExecStart = "${pkgs.docuum}/bin/docuum --threshold 40GB";
        Restart = "on-failure";
      };
    };
  };
}
