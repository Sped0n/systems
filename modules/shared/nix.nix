{
  determinate,
  functions,
  pkgs,
  vars,
  ...
}:
{
  nixpkgs = {
    config.allowUnfree = true;
    overlays = functions.loadOverlays (functions.fromRoot "/overlays");
  };

  nix = {
    settings = {
      trusted-users = [
        "${vars.username}"
        "@admin"
        "@wheel"
      ];
      experimental-features = "nix-command flakes";
      download-buffer-size = 524288000;
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
        "https://install.determinate.systems"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
      ];
    };
    extraOptions = ''
      builders-use-substitutes = true
    '';
  };

  environment.systemPackages = [
    (pkgs.nixos-rebuild-ng.override {
      nix = determinate.inputs.nix.packages."${pkgs.stdenv.system}".default;
    })
  ];
}
