{ lib, ... }:
{
  imports = [
    ./ccache.nix
    ./gc.nix
    ./generic-linux.nix
    ./nix.nix
  ];

  options.services.standalone.enable = lib.mkEnableOption "standalone Home Manager services";
}
