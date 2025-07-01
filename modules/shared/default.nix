{
  pkgs,
  specialArgs,
  username,
  ...
}: {
  imports = [
    ./secrets.nix
  ];

  # Nixpkgs
  nixpkgs = {
    config = {
      allowUnfree = true;
    };

    overlays =
      # Apply each overlay found in the /overlays directory
      let
        path = ../../overlays;
      in
        with builtins;
          map (n: import (path + ("/" + n)))
          (filter (n:
            match ".*\\.nix" n
            != null
            || pathExists (path + ("/" + n + "/default.nix")))
          (attrNames (readDir path)))
          ++ [];
  };

  # Nix
  nix = {
    package = pkgs.nix;
    settings = {
      trusted-users = ["${username}" "@admin"];
      experimental-features = "nix-command flakes";
      nix-path = ["nixpkgs=${pkgs.path}"];
      download-buffer-size = 524288000;
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
    gc = {
      automatic = true;
      options = "--delete-older-than 21d";
    };
  };

  # Home manager
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = specialArgs;
  };

  # Zsh
  programs.zsh.enable = true;
  environment = {
    shells = with pkgs; [zsh];
  };

  # Vim
  environment.systemPackages = with pkgs; [vim];
}
