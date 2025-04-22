{username, ...}: {
  imports = [
    ../../modules/nixos/server

    ./system.nix
    ./disko.nix
    ./secrets.nix

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
