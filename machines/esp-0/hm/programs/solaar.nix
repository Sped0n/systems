{ pkgs-unstable, ... }:
{
  home.packages = [ pkgs-unstable.solaar ];

  xdg.configFile."autostart/solaar.desktop".source =
    "${pkgs-unstable.solaar}/share/applications/solaar.desktop";
}
