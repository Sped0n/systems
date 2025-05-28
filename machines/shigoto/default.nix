{username, ...}: {
  imports = [
    ../../modules/nixos/desktop

    ./disko.nix

    ./system
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
