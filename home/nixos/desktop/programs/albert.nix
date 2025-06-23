{pkgs-unstable, ...}: {
  home.packages = with pkgs-unstable; [albert];

  systemd.user.services.albert = {
    Unit = {
      Description = "Albert Launcher";
      After = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };

    Service = {
      ExecStart = "${pkgs-unstable.albert}/bin/albert --platform wayland";
      Restart = "on-failure";
      RestartSec = "5s";
    };

    Install = {
      WantedBy = ["graphical-session.target"];
    };
  };
}
