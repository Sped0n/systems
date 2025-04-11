{username, ...}: {
  imports = [
    ../../modules/nixos/server

    ./system.nix
    ./disko.nix
    ./networking
    ./secrets.nix
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
