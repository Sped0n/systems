{
  determinate,
  pkgs,
  vars,
  ...
}:
{
  nix = {
    settings = {
      trusted-users = [
        "${vars.username}"
        "@admin"
        "@wheel"
      ];
      experimental-features = "nix-command flakes";
      download-buffer-size = 524288000;
      http-connections = 128;
      max-substitution-jobs = 128;
      substituters = [ "https://cache.nixos.org?priority=10" ];
      trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" ];
      extra-substituters = [
        "https://nix-community.cachix.org?priority=50"
        "https://install.determinate.systems?priority=60"
        "https://cache.numtide.com?priority=70"
      ];
      extra-trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
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
