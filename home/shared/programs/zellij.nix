{...}: {
  programs.zellij = {
    enable = true;
  };
  xdg.configFile."zellij/config.kdl".source = ../config/zellij.kdl;
}
