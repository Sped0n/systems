{
  home,
  pkgs,
  username,
  ...
}:
{
  imports = [
    ../shared
    ./system

    ./casks.nix
  ];

  nix.enable = false; # determinate

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
