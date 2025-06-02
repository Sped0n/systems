{username, ...}: {
  imports = [
    ../../modules/nixos/server

    ./system.nix
    ./secrets.nix
    ./disko.nix

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
    users.root = {...}: {
      imports = [./root-ssh.nix]; # for build-host/target-host deployment
      home = {
        enableNixpkgsReleaseCheck = false;
        stateVersion = "24.11";
      };
    };
  };

  system.stateVersion = "24.11";
}
