{ libutils, vars, ... }:
{
  imports = [
    (libutils.fromRoot "/modules/nixos/server")

    ./networking
    ./services

    ./builder.nix
    ./disko.nix
    ./system.nix
  ];

  home-manager = {
    users.${vars.username} =
      { ... }:
      {
        imports = [ ./home ];
        home = {
          enableNixpkgsReleaseCheck = false;
          stateVersion = "24.11";
        };
      };
  };

  system.stateVersion = "24.11";
}
