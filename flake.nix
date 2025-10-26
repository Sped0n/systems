{
  description = "systems";

  inputs = {
    # core
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.2505";
    nixpkgs-unstable.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0.1";
    determinate-nix-src.url = "https://flakehub.com/f/DeterminateSystems/nix-src/*";
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";

    # shared
    secrets = {
      url = "git+ssh://git@github.com/Sped0n/secrets";
      flake = false;
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # NixOS
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # macOS
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      determinate-nix-src,
      determinate,
      secrets,
      home-manager,
      agenix,
      disko,
      nix-darwin,
      nix-homebrew,
    }:
    let
      genSpecialArgs =
        {
          system,
          unstableConfigOverrides ? { },
          extraArgs ? { },
        }:
        let
        in
        rec {
          vars = import "${secrets}/vars" // rec {
            username = "spedon";
            home =
              if builtins.match ".*darwin$" system != null then "/Users/${username}" else "/home/${username}";
          };

          libutils = {
            loadOverlays = import ./functions/loadOverlays.nix;
            fromRoot = relPath: self.outPath + relPath;
          };

          pkgs-unstable = import nixpkgs-unstable {
            inherit system;
            config = {
              allowUnfree = true;
            }
            // unstableConfigOverrides;
            overlays = libutils.loadOverlays ./overlays;
          };
        }
        // extraArgs;

      commonNixosModules = [
        determinate.nixosModules.default
        disko.nixosModules.disko
        agenix.nixosModules.default
        home-manager.nixosModules.home-manager
      ];

      commonDarwinModules = [
        determinate.darwinModules.default
        agenix.darwinModules.default
        home-manager.darwinModules.home-manager
        nix-homebrew.darwinModules.nix-homebrew
      ];

      commonExtraArgs = {
        inherit
          self
          secrets
          agenix
          ;
      };
    in
    {
      darwinConfigurations = {
        "dendrobium" = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = genSpecialArgs {
            system = "aarch64-darwin";
            extraArgs = commonExtraArgs // {
              inherit determinate-nix-src;
            };
          };
          modules = commonDarwinModules ++ [ ./machines/dendrobium ];
        };
      };

      nixosConfigurations = {
        "stargazer" = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = genSpecialArgs {
            system = "x86_64-linux";
            unstableConfigOverrides = {
              permittedInsecurePackages = [ "beekeeper-studio-5.3.4" ];
            };
            extraArgs = commonExtraArgs;
          };
          modules = commonNixosModules ++ [ ./machines/stargazer ];
        };

        "unicorn" = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = genSpecialArgs {
            system = "x86_64-linux";
            extraArgs = commonExtraArgs;
          };
          modules = commonNixosModules ++ [ ./machines/unicorn ];
        };

        "banshee" = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = genSpecialArgs {
            system = "x86_64-linux";
            extraArgs = commonExtraArgs;
          };
          modules = commonNixosModules ++ [ ./machines/banshee ];
        };

        "calibarn" = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = genSpecialArgs {
            system = "aarch64-linux";
            extraArgs = commonExtraArgs;
          };
          modules = commonNixosModules ++ [ ./machines/calibarn ];
        };

        "exia" = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = genSpecialArgs {
            system = "x86_64-linux";
            extraArgs = commonExtraArgs;
          };
          modules = commonNixosModules ++ [ ./machines/exia ];
        };
      };
    };
}
