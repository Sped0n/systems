{ libutils, vars, ... }:
{
  home-manager.users.${vars.username} = {
    imports = [
      (libutils.fromRoot "/home/nixos/server")

      ./programs

      ./packages.nix
    ];
  };
}
