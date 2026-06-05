{ pkgs, ... }:
let
  ccacheDir = "/nix/var/cache/ccache";
in
{
  nix.settings.extra-sandbox-paths = [ ccacheDir ];
  environment.systemPackages = [ pkgs.ccache ];
  system.activationScripts.preActivation.text = ''
    install -d -m 0755 -o root -g nixbld '${dirOf ccacheDir}'
    install -d -m 0770 -o root -g nixbld '${ccacheDir}'
  '';
}
