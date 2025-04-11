{
  pkgs,
  specialArgs,
  username,
  ...
}: {
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
    };
    gc = {
      automatic = true;
      options = "--delete-older-than 14d";
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
    shells = [pkgs.zsh];
  };
}
