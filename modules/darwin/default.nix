{
  dix,
  home,
  pkgs,
  pkgs-unstable,
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

  environment.systemPackages = [
    (pkgs-unstable.nixos-rebuild-ng.override {
      nix = dix.packages."${pkgs.stdenv.system}".default;
    })
  ];

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
      "FastZip Pro" = 6740171321;
    };
  };
}
