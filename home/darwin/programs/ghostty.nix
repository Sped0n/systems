{...}: {
  programs.ghostty = {
    enable = true;
    package = null; # currently pkgs.ghostty is marked as broken
  };
}
