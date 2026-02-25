{ functions, vars, ... }:
{
  home-manager.users.${vars.username} = {
    imports = [
      (functions.fromRoot "/home/nixos/desktop")

      ./programs

      ./packages.nix
    ];
  };
}
