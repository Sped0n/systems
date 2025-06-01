{
  username,
  agenix,
  ...
}: {
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
      imports = [
        agenix.homeManagerModules.default

        ./home/programs/ssh.nix
        ./home/secrets.nix
      ];
      home = {
        enableNixpkgsReleaseCheck = false;
        stateVersion = "24.11";
      };
    };
  };

  system.stateVersion = "24.11";
}
