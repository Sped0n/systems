{
  determinate,
  pkgs,
  pkgs-unstable,
  ...
}:
{
  home.packages =
    (with pkgs; [
      docker
      minicom
      cdecl

      smartmontools

      ffmpeg
      imagemagick
    ])
    ++ [
      (pkgs-unstable.nixos-anywhere.override {
        nix = determinate.inputs.nix.packages."${pkgs.stdenv.system}".default;
      })
    ];
}
