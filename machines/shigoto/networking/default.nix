{...}: {
  imports = [
    ../../../modules/nixos/shared/networking.nix

    ./tailscale.nix
  ];

  networking = {
    hostName = "shigoto";
    nameservers = [
      "1.1.1.1"
      "8.8.8.8"
      "2606:4700:4700::1111"
      "2001:4860:4860::8888"
    ];
  };
}
