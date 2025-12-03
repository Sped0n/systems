{ functions, vars, ... }:
{
  home-manager.users."${vars.username}" = {
    imports = [
      (functions.fromRoot "/home/nixos/server")

      ./programs

      ./packages.nix
    ];
  };
}
