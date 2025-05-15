{pkgs, ...}: {
  programs.ghostty = {
    enable = true;
    package = null; # use the snap version
    settings = {
      font-family = "Lilex Medium";
      font-size = 12;
      clipboard-read = "allow";
    };
  };

  home.packages = [pkgs.lilex];
}
