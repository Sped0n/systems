{
  description = "worst nix config on this planet";

  inputs = {
    # Core
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.11";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Misc
    secrets = {
      url = "git+ssh://git@github.com/Sped0n/secrets";
      flake = false;
    };

    # NixOS
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Darwin
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-rosetta-builder = {
      url = "github:cpick/nix-rosetta-builder";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    nixpkgs-stable,
    home-manager,
    agenix,
    secrets,
    disko,
    nix-darwin,
    nix-homebrew,
    nix-rosetta-builder,
  }: let
    vars = import "${secrets}/vars";
    username = "spedon";
  in {
    darwinConfigurations."ringo" = nix-darwin.lib.darwinSystem rec {
      system = "aarch64-darwin";
      specialArgs =
        {
          inherit vars username;
          home = "/Users/${username}";
          pkgs-stable = import nixpkgs-stable {
            inherit system;
            config.allowUnfree = true;
          };
        }
        // inputs;
      modules = [
        home-manager.darwinModules.home-manager
        nix-homebrew.darwinModules.nix-homebrew
        agenix.darwinModules.default
        nix-rosetta-builder.darwinModules.default
        ./machines/ringo
      ];
    };

    nixosConfigurations."tsuki" = nixpkgs.lib.nixosSystem rec {
      system = "x86_64-linux";
      specialArgs =
        {
          inherit vars username;
          home = "/home/${username}";
          pkgs-stable = import nixpkgs-stable {
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

    nixosConfigurations."tennousei" = nixpkgs.lib.nixosSystem rec {
      system = "x86_64-linux";
      specialArgs =
        {
          inherit vars username;
          home = "/home/${username}";
          pkgs-stable = import nixpkgs-stable {
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
  };
}
