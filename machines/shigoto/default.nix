{username, ...}: {
  imports = [
    ../../modules/nixos/desktop

    ./disko.nix
    ./gpg-key.nix

    ./system
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
