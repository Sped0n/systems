{
  pkgs,
  pkgs-unstable,
  specialArgs,
  username,
  ...
}:
{
  imports = [
    ./agenix.nix
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
      map (n: import (path + ("/" + n))) (
        filter (n: match ".*\\.nix" n != null || pathExists (path + ("/" + n + "/default.nix"))) (
          attrNames (readDir path)
        )
      )
      ++ [ ];
  };

  # Nix
  nix.settings = {
    trusted-users = [
      "${username}"
      "@admin"
    ];
    experimental-features = "nix-command flakes";
    download-buffer-size = 524288000;
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://install.determinate.systems"
    ];
    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
    ];
  };

  # Home Manager
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = specialArgs;
  };

  # Zsh
  programs.zsh.enable = true;
  environment = {
    shells = with pkgs; [ zsh ];
  };

  # System Packages
  environment.systemPackages = [
    pkgs.vim
    pkgs-unstable.nixos-rebuild-ng
  ];
}
