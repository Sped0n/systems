{
  pkgs,
  username,
  home,
  ...
}: {
  imports = [
    ../shared

    ./system.nix
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
    casks = pkgs.callPackage ./casks.nix {};
    onActivation = {
      autoUpdate = false;
      upgrade = true;
      cleanup = "zap";
    };

    # nix run nixpkgs#mas search XXX
    masApps = {
      "Bitwarden" = 1352778147;
      "Windows App" = 1295203466;
      "Dropover" = 1355679052;
      "Microsoft Word" = 462054704;
      "Microsoft Excel" = 462058435;
      "Microsoft PowerPoint" = 462062816;
      "Microsoft Outlook" = 985367838;
      "Microsoft OneDrive" = 823766827;
      "PDFgear" = 6469021132;
      "FastZip Pro" = 6740171321;
    };
  };

  # Fonts
  fonts = {
    packages = with pkgs; [
      lilex
    ];
  };
}
