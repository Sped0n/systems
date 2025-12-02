{ libutils, vars, ... }:
{
  home-manager.users.${vars.username} = {
    imports = [
      (libutils.fromRoot "/home/darwin")

      ./programs

      ./packages.nix
    ];
  };
}
