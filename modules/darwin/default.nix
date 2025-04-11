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
    Weekday = 0;
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

    # These app IDs are from using the mas CLI app
    # mas = mac app store
    # https://github.com/mas-cli/mas
    #
    # $ nix shell nixpkgs#mas
    # $ mas search <app name>
    #
    # If you have previously added these apps to your Mac App Store profile (but not installed them on this system),
    # you may receive an error message "Redownload Unavailable with This Apple ID".
    # This message is safe to ignore. (https://github.com/dustinlyons/nixos-config/issues/83)
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
    };
  };

  # Fonts
  fonts = {
    packages = with pkgs; [
      lilex
    ];
  };
}
