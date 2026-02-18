{
  description = "systems";

  inputs = {
    # core
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.2511";
    nixpkgs-unstable.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1";
    nixpkgs-swift.url = "https://flakehub.com/f/NixOS/nixpkgs/=0.1.927018";
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";

    # shared
    secrets = {
      url = "git+ssh://git@github.com/Sped0n/secrets";
      flake = false;
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents.url = "github:numtide/llm-agents.nix";

    # NixOS
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # macOS
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nixpkgs-unstable,
      determinate,
      secrets,
      home-manager,
      agenix,
      disko,
      nix-darwin,
      nix-homebrew,
      ...
    }:
    let
      genSpecialArgs =
        {
          system,
          extraArgs ? { },
        }:
        rec {
          inherit agenix determinate secrets;

          vars = import "${secrets}/vars" // rec {
            username = "spedon";
            home =
              if builtins.match ".*darwin$" system != null then "/Users/${username}" else "/home/${username}";
            serverHostnames = [
              "srv-de-0"
              "srv-hk-0"
              "srv-jp-0"
              "srv-nl-0"
              "srv-sg-0"
              "srv-sg-1"
              "srv-us-0"
            ];
          };

          functions = import ./functions {
            lib = nixpkgs.lib;
            inherit self;
          };
        }
        // extraArgs;

      overlaysList =
        (import ./functions {
          lib = nixpkgs.lib;
          inherit self;
        }).loadOverlays
          {
            overlayDirectory = ./overlays;
            args = { inherit inputs; };
          };

      nixpkgsModule =
        { ... }:
        {
          nixpkgs = {
            config.allowUnfree = true;
            overlays = overlaysList;
          };
        };

      pkgsUnstableFor =
        system:
        import nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
          overlays = overlaysList;
        };

      commonNixosModules = [
        nixpkgsModule
        determinate.nixosModules.default
        disko.nixosModules.disko
        agenix.nixosModules.default
        home-manager.nixosModules.home-manager
      ];

      commonDarwinModules = [
        nixpkgsModule
        determinate.darwinModules.default
        agenix.darwinModules.default
        home-manager.darwinModules.home-manager
        nix-homebrew.darwinModules.nix-homebrew
      ];
    in
    {
      darwinConfigurations = {
        "wks-0" = nix-darwin.lib.darwinSystem rec {
          system = "aarch64-darwin";
          specialArgs = (genSpecialArgs { inherit system; }) // {
            pkgs-unstable = pkgsUnstableFor system;
          };
          modules = commonDarwinModules ++ [ ./machines/wks-0 ];
        };
      };

      nixosConfigurations = {
        "srv-de-0" = nixpkgs.lib.nixosSystem rec {
          system = "x86_64-linux";
          specialArgs = (genSpecialArgs { inherit system; }) // {
            pkgs-unstable = pkgsUnstableFor system;
          };
          modules = commonNixosModules ++ [ ./machines/srv-de-0 ];
        };

        "srv-hk-0" = nixpkgs.lib.nixosSystem rec {
          system = "x86_64-linux";
          specialArgs = (genSpecialArgs { inherit system; }) // {
            pkgs-unstable = pkgsUnstableFor system;
          };
          modules = commonNixosModules ++ [ ./machines/srv-hk-0 ];
        };

        "srv-jp-0" = nixpkgs.lib.nixosSystem rec {
          system = "x86_64-linux";
          specialArgs = (genSpecialArgs { inherit system; }) // {
            pkgs-unstable = pkgsUnstableFor system;
          };
          modules = commonNixosModules ++ [ ./machines/srv-jp-0 ];
        };

        "srv-nl-0" = nixpkgs.lib.nixosSystem rec {
          system = "x86_64-linux";
          specialArgs = (genSpecialArgs { inherit system; }) // {
            pkgs-unstable = pkgsUnstableFor system;
          };
          modules = commonNixosModules ++ [ ./machines/srv-nl-0 ];
        };

        "srv-sg-0" = nixpkgs.lib.nixosSystem rec {
          system = "x86_64-linux";
          specialArgs = (genSpecialArgs { inherit system; }) // {
            pkgs-unstable = pkgsUnstableFor system;
          };
          modules = commonNixosModules ++ [ ./machines/srv-sg-0 ];
        };

        "srv-sg-1" = nixpkgs.lib.nixosSystem rec {
          system = "aarch64-linux";
          specialArgs = (genSpecialArgs { inherit system; }) // {
            pkgs-unstable = pkgsUnstableFor system;
          };
          modules = commonNixosModules ++ [ ./machines/srv-sg-1 ];
        };

        "srv-us-0" = nixpkgs.lib.nixosSystem rec {
          system = "x86_64-linux";
          specialArgs = (genSpecialArgs { inherit system; }) // {
            pkgs-unstable = pkgsUnstableFor system;
          };
          modules = commonNixosModules ++ [ ./machines/srv-us-0 ];
        };
      };
    };
}
