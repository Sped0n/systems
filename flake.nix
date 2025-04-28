{
  description = "worst nix config on this planet";

  inputs = {
    # Core
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.11";

    # Misc
    secrets = {
      url = "git+ssh://git@github.com/Sped0n/secrets";
      flake = false;
    };

    # NixOS
    home-manager = {
      url = "github:nix-community/home-manager";
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
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };
    agenix-darwin = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };
    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };
    nix-rosetta-builder = {
      url = "github:cpick/nix-rosetta-builder";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    nixpkgs-darwin,
    # nixpkgs-stable,
    secrets,
    home-manager,
    agenix,
    disko,
    home-manager-darwin,
    agenix-darwin,
    nix-darwin,
    nix-homebrew,
    nix-rosetta-builder,
  }: let
    vars = import "${secrets}/vars";
    username = "spedon";
  in {
    darwinConfigurations."ringo" =
      nix-darwin.lib.darwinSystem
      # rec
      {
        system = "aarch64-darwin";
        specialArgs =
          {
            inherit vars username;
            home = "/Users/${username}";
            # pkgs-stable = import nixpkgs-stable {
            #   inherit system;
            #   config.allowUnfree = true;
            # };
          }
          // inputs;
        modules = [
          home-manager-darwin.darwinModules.home-manager
          nix-homebrew.darwinModules.nix-homebrew
          agenix-darwin.darwinModules.default
          nix-rosetta-builder.darwinModules.default
          ./machines/ringo
        ];
      };

    nixosConfigurations."tsuki" =
      nixpkgs.lib.nixosSystem
      # rec
      {
        system = "x86_64-linux";
        specialArgs =
          {
            inherit vars username;
            home = "/home/${username}";
            # pkgs-stable = import nixpkgs-stable {
            #   inherit system;
            #   config.allowUnfree = true;
            # };
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
      # rec
      {
        system = "x86_64-linux";
        specialArgs =
          {
            inherit vars username;
            home = "/home/${username}";
            # pkgs-stable = import nixpkgs-stable {
            #   inherit system;
            #   config.allowUnfree = true;
            # };
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
