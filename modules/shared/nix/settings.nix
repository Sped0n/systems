{
  nixpkgs,
  nixpkgs-unstable,
  vars,
  ...
}:
{
  nix.registry = {
    nixpkgs.flake = nixpkgs;
    nixpkgs-unstable.flake = nixpkgs-unstable;
  };

  nix.settings = {
    trusted-users = [
      "${vars.username}"
      "@admin"
      "@wheel"
    ];
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    log-lines = 25;
    download-buffer-size = 524288000;
    http-connections = 32;
    max-substitution-jobs = 32;
    connect-timeout = 5;
    fallback = true;
    builders-use-substitutes = true;
    substituters = [
      "https://aseipp-nix-cache.global.ssl.fastly.net?priority=9"
      "https://cache.nixos.org?priority=10"
      "https://nix-cache.sped0n.com/nix-cache?priority=30"
      "https://nix-community.cachix.org?priority=50"
      "https://cache.numtide.com?priority=70"
      "https://mirror.sjtu.edu.cn/nix-channels/store?priority=80"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-cache.sped0n.com-1:2QjPOhbTs8xHYPpe0tuGIQQ+DFmEZMv05UAfHzU9Crg="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };
}
