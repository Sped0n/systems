{ functions, vars, ... }:
{
  home-manager.users.${vars.username} = {
    imports = [
      (functions.fromRoot "/hm/darwin")

      ./programs

      ./packages.nix
    ];
  };
}
