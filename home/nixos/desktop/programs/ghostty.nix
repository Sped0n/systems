{pkgs-unstable, ...}: {
  programs.ghostty = {
    enable = true;
    package = pkgs-unstable.ghostty;
    settings = {
      font-family = "Lilex Medium";
      font-size = 12;
    };
  };

  home.packages = [pkgs-unstable.lilex];
}
