{
  config,
  determinate-nix-src,
  libutils,
  pkgs,
  pkgs-unstable,
  vars,
  ...
}:
{
  imports = [
    (libutils.fromRoot "/modules/shared")

    ./system

    ./casks.nix
    ./diff.nix
  ];

  nix.enable = false;
  determinate-nix.customSettings = config.nix.settings // {
    builders-use-substitutes = true;
  };

  environment.systemPackages = [
    (pkgs-unstable.nixos-rebuild-ng.override {
      nix = determinate-nix-src.packages."${pkgs.stdenv.system}".default;
    })
  ];

  users.users = {
    ${vars.username} = {
      home = vars.home;
      name = "${vars.username}";
      shell = pkgs.zsh;
    };
  };

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = false;
      upgrade = true;
      cleanup = "zap";
    };

    # nix run nixpkgs#mas search XXX
    masApps = {
      "Bitwarden" = 1352778147;
    };
  };
}
