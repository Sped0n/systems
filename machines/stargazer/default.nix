{ username, ... }:
{
  imports = [
    ../../modules/nixos/desktop

    ./system
    ./services
    ./networking.nix
    ./disko.nix
    ./agenix.nix
  ];

  home-manager = {
    users.${username} =
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
