{ pkgs, ... }:
let
  ccacheDir = "/nix/var/cache/ccache";
in
{
  nix.settings.extra-sandbox-paths = [ ccacheDir ];
  environment.systemPackages = [ pkgs.ccache ];
  systemd.tmpfiles.rules = [
    "d ${dirOf ccacheDir} 0755 root nixbld -"
    "d ${ccacheDir} 0770 root nixbld -"
  ];
}
