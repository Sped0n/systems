{
  lib,
  pkgs-unstable,
  ...
}: {
  programs.uv = {
    enable = lib.mkDefault false;
    package = pkgs-unstable.uv;
    settings = {
      python-downloads = "never";
      python-preference = "only-system";
    };
  };
}
