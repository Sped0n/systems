{username, ...}: {
  imports = [
    ../../modules/nixos/desktop

    ./system.nix
    ./disko.nix

    ./networking
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
