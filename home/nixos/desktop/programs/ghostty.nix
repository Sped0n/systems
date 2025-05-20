{pkgs, ...}: {
  programs.ghostty = {
    enable = true;
    settings = {
      font-family = "Lilex Medium";
      font-size = 12;
    };
  };

  home.packages = [pkgs.lilex];
}
