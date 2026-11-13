{
  description = "systems";

  inputs = {
    # core
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    # shared
    secrets = {
      url = "git+ssh://git@github.com/Sped0n/secrets";
      flake = false;
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-cache-push = {
      url = "github:Sped0n/nix-cache-push";
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
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs =
    inputs:
    let
      varsFor =
        system:
        import "${inputs.secrets}/vars"
        // rec {
          username = "spedon";
          home =
            if builtins.match ".*darwin$" system != null then "/Users/${username}" else "/home/${username}";
          serverHostnames = builtins.attrNames (
            inputs.nixpkgs.lib.filterAttrs (
              name: type: type == "directory" && inputs.nixpkgs.lib.hasPrefix "srv-" name
            ) (builtins.readDir ./machines)
          );
        };

      inherit (import ./functions/mkConfigurations.nix { inherit inputs varsFor; })
        mkNixos
        mkDarwin
        mkHome
        pkgsFor
        pkgsUnstableFor
        ;
    in
    {
      devShells = import ./functions/mkDevShells.nix {
        lib = inputs.nixpkgs.lib;
        inherit pkgsFor pkgsUnstableFor;
      };

      darwinConfigurations = {
        "dlp-0" = mkDarwin {
          system = "aarch64-darwin";
          modules = [ ./machines/dlp-0 ];
        };
      };

      nixosConfigurations = {
        "srv-de-0" = mkNixos {
          system = "x86_64-linux";
          modules = [ ./machines/srv-de-0 ];
        };

        "srv-jp-0" = mkNixos {
          system = "x86_64-linux";
          modules = [ ./machines/srv-jp-0 ];
        };

        "srv-nl-0" = mkNixos {
          system = "x86_64-linux";
          modules = [ ./machines/srv-nl-0 ];
        };

        "srv-sg-0" = mkNixos {
          system = "x86_64-linux";
          modules = [ ./machines/srv-sg-0 ];
        };

        "srv-sg-1" = mkNixos {
          system = "aarch64-linux";
          modules = [ ./machines/srv-sg-1 ];
        };

        "srv-us-0" = mkNixos {
          system = "x86_64-linux";
          modules = [ ./machines/srv-us-0 ];
        };
      };

      homeConfigurations = {
        "esp-sh-0" = mkHome {
          system = "x86_64-linux";
          username = "spedon";
          homeDirectory = "/home/spedon";
          stateVersion = "26.05";
          modules = [ ./machines/esp-sh-0 ];
        };

        "esp-sg-0" = mkHome {
          system = "x86_64-linux";
          username = "spedon";
          homeDirectory = "/home/spedon";
          stateVersion = "26.05";
          modules = [ ./machines/esp-sg-0 ];
        };
      };
    };
}
