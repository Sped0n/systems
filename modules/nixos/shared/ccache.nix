{ pkgs, ... }:
let
  ccacheDir = "/nix/var/cache/ccache";
in
{
  nix.settings.extra-sandbox-paths = [ ccacheDir ];
  environment.systemPackages = [ pkgs.ccache ];
  systemd.tmpfiles.rules = [
    "d ${ccacheDir} 0770 root nixbld -"
  ];
}
