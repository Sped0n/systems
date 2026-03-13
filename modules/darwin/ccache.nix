{ pkgs, ... }:
let
  ccacheDir = "/nix/var/cache/ccache";
in
{
  nix.settings.extra-sandbox-paths = [ ccacheDir ];
  environment.systemPackages = [ pkgs.ccache ];
  system.activationScripts.preActivation.text = ''
    mkdir -p ${ccacheDir}
    chown root:nixbld ${ccacheDir}
    chmod 0770 ${ccacheDir}
  '';
}
