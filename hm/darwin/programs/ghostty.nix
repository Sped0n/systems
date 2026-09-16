{ ... }:
{
  programs.ghostty = {
    enable = true;
    package = null; # currently pkgs.ghostty is marked as broken
    settings.auto-update-channel = "tip"; # FIXME: workaround for https://github.com/ghostty-org/ghostty/issues/13070
  };
}
