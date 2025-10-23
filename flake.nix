{
  description = "systems";

  inputs = {
    # Core
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-qemu8.url = "github:NixOS/nixpkgs/3eebbc5fe26801ff612f2cdd4566e76651dc8106";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-25.05-darwin";
    nixpkgs-darwin-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # Misc
    dix.url = "https://flakehub.com/f/DeterminateSystems/nix-src/*";
    secrets = {
      url = "git+ssh://git@github.com/Sped0n/secrets";
      flake = false;
    };

    # NixOS
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Darwin
    home-manager-darwin = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };
    agenix-darwin = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.05";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nixpkgs-unstable,
      nixpkgs-qemu8,
      nixpkgs-darwin,
      nixpkgs-darwin-unstable,
      dix,
      secrets,
      determinate,
      home-manager,
      agenix,
      disko,
      home-manager-darwin,
      agenix-darwin,
      nix-darwin,
      nix-homebrew,
    }:
    let
      lib = nixpkgs.lib;
      vars = import "${inputs.secrets}/vars";
      username = "spedon";

      genSpecialArgs =
        {
          system,
          unstablePkgsInput,
          unstableConfigOverrides ? { },
          extraArgs ? { },
        }:
        {
          inherit vars username;
          home = if lib.strings.hasSuffix "darwin" system then "/Users/${username}" else "/home/${username}";

          pkgs-unstable = import unstablePkgsInput {
            inherit system;
            config = {
              allowUnfree = true;
            }
            // unstableConfigOverrides;
            overlays =
              # Apply each overlay found in the /overlays directory
              let
                path = ./overlays;
              in
              with builtins;
              map (n: import (path + ("/" + n))) (
                filter (n: match ".*\\.nix" n != null || pathExists (path + ("/" + n + "/default.nix"))) (
                  attrNames (readDir path)
                )
              )
              ++ [ ];
          };
        }
        // extraArgs
        // inputs;

      commonNixosModules = [
        determinate.nixosModules.default
        disko.nixosModules.disko
        agenix.nixosModules.default
        home-manager.nixosModules.home-manager
      ];

      commonDarwinModules = [
        home-manager-darwin.darwinModules.home-manager
        agenix-darwin.darwinModules.default
        nix-homebrew.darwinModules.nix-homebrew
      ];
    in
    {
      darwinConfigurations = {
        "dendrobium" = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = genSpecialArgs {
            system = "aarch64-darwin";
            unstablePkgsInput = nixpkgs-darwin-unstable;
          };
          modules = commonDarwinModules ++ [ ./machines/dendrobium ];
        };
      };

      nixosConfigurations = {
        "stargazer" = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = genSpecialArgs {
            system = "x86_64-linux";
            unstablePkgsInput = nixpkgs-unstable;
            unstableConfigOverrides = {
              permittedInsecurePackages = [ "beekeeper-studio-5.3.4" ];
            };
          };
          modules = commonNixosModules ++ [ ./machines/stargazer ];
        };

        "unicorn" = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = genSpecialArgs {
            system = "x86_64-linux";
            unstablePkgsInput = nixpkgs-unstable;
          };
          modules = commonNixosModules ++ [ ./machines/unicorn ];
        };

        "banshee" = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = genSpecialArgs {
            system = "x86_64-linux";
            unstablePkgsInput = nixpkgs-unstable;
          };
          modules = commonNixosModules ++ [ ./machines/banshee ];
        };

        "calibarn" = nixpkgs.lib.nixosSystem rec {
          system = "aarch64-linux";
          specialArgs = genSpecialArgs {
            system = "aarch64-linux";
            unstablePkgsInput = nixpkgs-unstable;
            extraArgs = {
              pkgs-qemu8 = import inputs.nixpkgs-qemu8 {
                inherit system;
              };
            };
          };
          modules = commonNixosModules ++ [ ./machines/calibarn ];
        };

        "exia" = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = genSpecialArgs {
            system = "x86_64-linux";
            unstablePkgsInput = nixpkgs-unstable;
          };
          modules = commonNixosModules ++ [ ./machines/exia ];
        };
      };
    };
}
