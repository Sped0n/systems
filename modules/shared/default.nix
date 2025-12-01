{
  config,
  determinate,
  libutils,
  pkgs,
  pkgs-unstable,
  secrets,
  specialArgs,
  vars,
  ...
}:
{
  nixpkgs = {
    config = {
      allowUnfree = true;
    };

    overlays = libutils.loadOverlays (libutils.fromRoot "/overlays");
  };

  nix = {
    settings = {
      trusted-users = [
        "${vars.username}"
        "@admin"
        "@wheel"
      ];
      experimental-features = "nix-command flakes";
      download-buffer-size = 524288000;
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
        "https://install.determinate.systems"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
      ];
    };
    extraOptions = ''
      		builders-use-substitutes = true
      	'';
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = specialArgs;
  };

  programs.zsh.enable = true;
  environment = {
    shells = with pkgs; [ zsh ];
  };

  environment.systemPackages = [
    pkgs.vim
    (pkgs-unstable.nixos-rebuild-ng.override {
      nix = determinate.inputs.nix.packages."${pkgs.stdenv.system}".default;
    })
  ];

  age = {
    identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets."ssh_user_ed25519_key" = {
      file = "${secrets}/ages/${config.networking.hostName}-user.age";
      owner = vars.username;
      mode = "0400";
      path = "/etc/ssh/ssh_user_ed25519_key";
    };
  };
}
