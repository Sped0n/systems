{
  description = "worst nix config on this planet";

  inputs = {
    # Core
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-qemu8.url = "github:NixOS/nixpkgs/3eebbc5fe26801ff612f2cdd4566e76651dc8106";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-25.05-darwin";
    nixpkgs-darwin-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # Misc
    secrets = {
      url = "git+ssh://git@github.com/Sped0n/secrets";
      flake = false;
    };

    # NixOS
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
    nix-rosetta-builder = {
      url = "github:cpick/nix-rosetta-builder";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    nixpkgs-unstable,
    nixpkgs-qemu8,
    nixpkgs-darwin,
    nixpkgs-darwin-unstable,
    secrets,
    home-manager,
    agenix,
    disko,
    home-manager-darwin,
    agenix-darwin,
    nix-darwin,
    nix-rosetta-builder,
    nix-homebrew,
  }: let
    vars = import "${secrets}/vars";
    username = "spedon";
  in {
    darwinConfigurations."ringo" =
      nix-darwin.lib.darwinSystem
      rec
      {
        system = "aarch64-darwin";
        specialArgs =
          {
            inherit vars username;
            home = "/Users/${username}";
            pkgs-unstable = import nixpkgs-darwin-unstable {
              inherit system;
              config.allowUnfree = true;
            };
          }
          // inputs;
        modules = [
          home-manager-darwin.darwinModules.home-manager
          agenix-darwin.darwinModules.default
          nix-rosetta-builder.darwinModules.default
          nix-homebrew.darwinModules.nix-homebrew
          ./machines/ringo
        ];
      };

    nixosConfigurations."tsuki" =
      nixpkgs.lib.nixosSystem
      rec
      {
        system = "x86_64-linux";
        specialArgs =
          {
            inherit vars username;
            home = "/home/${username}";
            pkgs-unstable = import nixpkgs-unstable {
              inherit system;
              config.allowUnfree = true;
            };
          }
          // inputs;
        modules = [
          disko.nixosModules.disko
          agenix.nixosModules.default
          home-manager.nixosModules.home-manager
          ./machines/tsuki
        ];
      };

    nixosConfigurations."tennousei" =
      nixpkgs.lib.nixosSystem
      rec
      {
        system = "x86_64-linux";
        specialArgs =
          {
            inherit vars username;
            home = "/home/${username}";
            pkgs-unstable = import nixpkgs-unstable {
              inherit system;
              config.allowUnfree = true;
            };
          }
          // inputs;
        modules = [
          disko.nixosModules.disko
          agenix.nixosModules.default
          home-manager.nixosModules.home-manager
          ./machines/tennousei
        ];
      };

    nixosConfigurations."shigoto" =
      nixpkgs.lib.nixosSystem
      rec
      {
        system = "x86_64-linux";
        specialArgs =
          {
            inherit vars username;
            home = "/home/${username}";
            pkgs-unstable = import nixpkgs-unstable {
              inherit system;
              config = {
                allowUnfree = true;
                permittedInsecurePackages = [
                  "beekeeper-studio-5.2.9"
                ];
              };
            };
          }
          // inputs;
        modules = [
          disko.nixosModules.disko
          agenix.nixosModules.default
          home-manager.nixosModules.home-manager
          ./machines/shigoto
        ];
      };

    nixosConfigurations."suisei" =
      nixpkgs.lib.nixosSystem
      rec
      {
        system = "aarch64-linux";
        specialArgs =
          {
            inherit vars username;
            home = "/home/${username}";
            pkgs-unstable = import nixpkgs-unstable {
              inherit system;
              config = {
                allowUnfree = true;
              };
            };
            pkgs-qemu8 = import nixpkgs-qemu8 {
              inherit system;
              config = {
                allowUnfree = true;
              };
            };
          }
          // inputs;
        modules = [
          disko.nixosModules.disko
          agenix.nixosModules.default
          home-manager.nixosModules.home-manager
          ./machines/suisei
        ];
      };
  };
}
