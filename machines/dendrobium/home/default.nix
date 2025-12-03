{ functions, vars, ... }:
{
  home-manager.users.${vars.username} = {
    imports = [
      (functions.fromRoot "/home/darwin")

      ./programs

      ./packages.nix
    ];
  };
}
