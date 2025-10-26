{ libutils, vars, ... }:
{
  imports = [
    (libutils.fromRoot "/modules/nixos/server")

    ./system.nix
    ./disko.nix
    ./networking.nix
    ./services
    ./builder
  ];

  home-manager.users."${vars.username}" =
    { ... }:
    {
      imports = [ ./home ];
      home = {
        enableNixpkgsReleaseCheck = false;
        stateVersion = "24.11";
      };
    };

  system.stateVersion = "24.11";
}
