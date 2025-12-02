{
  config,
  libutils,
  pkgs,
  vars,
  ...
}:
{
  imports = [
    (libutils.fromRoot "/modules/shared")

    ./system

    ./casks.nix
    ./diff.nix
    ./gc.nix
    ./networking.nix
  ];

  nix.enable = false;
  determinate-nix.customSettings = config.nix.settings // {
    builders-use-substitutes = true;
  };

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
      "Quantumult X" = 1443988620;
    };
  };
}
