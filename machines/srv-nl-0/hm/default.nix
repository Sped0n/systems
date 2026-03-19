{ functions, vars, ... }:
{
  home-manager.users.${vars.username} = {
    imports = [
      (functions.fromRoot "/hm/nixos/server")

      ./programs

      ./packages.nix
    ];
  };
}
