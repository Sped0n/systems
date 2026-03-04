{
  functions,
  modulesPath,
  pkgs,
  pkgs-unstable,
  ...
}:
{
  imports = [
    (functions.fromRoot "/modules/shared/nix.nix")
    (modulesPath + "/installer/cd-dvd/installation-cd-graphical-gnome.nix")

    ./size-reduction.nix
  ];

  networking.hostName = "iso-0";
  system.stateVersion = "24.11";

  environment.systemPackages =
    (with pkgs; [
      agenix-cli
      disko
      firefox
      openssh
      vim
    ])
    ++ (with pkgs-unstable; [
      just
      btop
    ]);

  zramSwap = {
    enable = true;
    memoryPercent = 50;
    priority = 100;
  };
}
