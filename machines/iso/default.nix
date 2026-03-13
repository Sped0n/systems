{
  functions,
  modulesPath,
  pkgs,
  pkgs-unstable,
  ...
}:
{
  disabledModules = [ "profiles/base.nix" ];

  imports = [
    (functions.fromRoot "/modules/shared/nix")
    (modulesPath + "/installer/cd-dvd/installation-cd-graphical-gnome.nix")

    ./profiles-base-no-vim-and-zfs.nix
    ./size-reduction.nix
  ];

  system.stateVersion = "24.11";

  environment.systemPackages =
    (with pkgs; [
      agenix-cli
      disko
      firefox
      openssh
      wl-clipboard
    ])
    ++ (with pkgs-unstable; [
      just
      btop
    ]);

  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };
  environment.variables.VISUAL = "nvim";

  zramSwap = {
    enable = true;
    memoryPercent = 50;
    priority = 100;
  };
}
