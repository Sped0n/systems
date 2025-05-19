{pkgs, ...}: {
  programs.ghostty = {
    enable = true;
    settings = {
      font-family = "Lilex Medium";
      font-size = 12;
      clipboard-read = "allow";
    };
  };

  home.packages = [pkgs.lilex];
}
