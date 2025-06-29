{
  pkgs,
  username,
  home,
  ...
}: {
  imports = [
    ../shared

    ./system.nix
    ./casks.nix
  ];

  nix.gc.interval = {
    Hour = 0;
    Minute = 0;
  };

  users.users.${username} = {
    inherit home;
    name = "${username}";
    shell = pkgs.zsh;
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
      "Dropover" = 1355679052;
      "FastZip Pro" = 6740171321;
      "Microsoft Outlook" = 985367838;
    };
  };
}
