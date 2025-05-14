{pkgs, ...}: {
  programs.ghostty = {
    enable = true;
    package = null; # use the snap version
    settings = {
      font-family = "Lilex Medium";
      font-size = 12;
    };
  };

  home.packages = [pkgs.lilex];
}
