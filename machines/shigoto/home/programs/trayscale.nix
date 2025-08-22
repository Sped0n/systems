{ pkgs-unstable, ... }:
{
  home.packages = with pkgs-unstable; [ trayscale ];

  systemd.user.services.trayscale = {
    Unit = {
      Description = "Unofficial GUI wrapper around the Tailscale CLI client";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${pkgs-unstable.trayscale}/bin/trayscale";
      Restart = "on-failure";
      RestartSec = "5s";
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
