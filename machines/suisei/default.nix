{username, ...}: {
  imports = [
    ../../modules/nixos/server

    ./system.nix
    ./disko.nix
    ./deployer.nix

    ./networking
    ./services
  ];

  home-manager = {
    users.${username} = {...}: {
      imports = [./home];
      home = {
        enableNixpkgsReleaseCheck = false;
        stateVersion = "24.11";
      };
    };
  };

  system.stateVersion = "24.11";
}
