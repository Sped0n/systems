{ inputs, varsFor }:
let
  inherit (inputs)
    self
    nixpkgs
    nixpkgs-unstable
    secrets
    home-manager
    agenix
    disko
    nix-darwin
    nix-homebrew
    ;

  functions = import ./. {
    lib = nixpkgs.lib;
    inherit self;
  };

  overlaysList = functions.loadOverlays {
    overlayDirectory = ../overlays;
    args = { inherit inputs; };
  };

  nixpkgsConfig = {
    allowUnfree = true;
  };

  pkgsFor =
    system:
    import nixpkgs {
      inherit system;
      config = nixpkgsConfig;
      overlays = overlaysList;
    };

  pkgsUnstableFor =
    system:
    import nixpkgs-unstable {
      inherit system;
      config = nixpkgsConfig;
      overlays = overlaysList;
    };

  genSpecialArgs = system: {
    inherit
      agenix
      nixpkgs
      nixpkgs-unstable
      secrets
      functions
      ;

    pkgs-unstable = pkgsUnstableFor system;

    vars = varsFor system;
  };

  nixpkgsModule =
    { ... }:
    {
      nixpkgs = {
        config = nixpkgsConfig;
        overlays = overlaysList;
      };
    };
in
{
  inherit pkgsFor pkgsUnstableFor;

  mkNixos =
    { system, modules }:
    nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = genSpecialArgs system;
      modules = [
        nixpkgsModule
        disko.nixosModules.disko
        agenix.nixosModules.default
        home-manager.nixosModules.home-manager
      ]
      ++ modules;
    };

  mkDarwin =
    { system, modules }:
    nix-darwin.lib.darwinSystem {
      inherit system;
      specialArgs = genSpecialArgs system;
      modules = [
        nixpkgsModule
        agenix.darwinModules.default
        home-manager.darwinModules.home-manager
        nix-homebrew.darwinModules.nix-homebrew
      ]
      ++ modules;
    };

  mkHome =
    {
      system,
      username,
      homeDirectory,
      stateVersion,
      modules,
    }:
    home-manager.lib.homeManagerConfiguration {
      pkgs = pkgsFor system;
      extraSpecialArgs = genSpecialArgs system;
      modules = [
        {
          home = {
            inherit username homeDirectory stateVersion;
          };
        }
      ]
      ++ modules;
    };
}
