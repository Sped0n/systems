{pkgs, ...}: {
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [
      # NOTE:
      # While manually adding input source in fcitx config
      # GUI, search cn/pinyin instead of Chinese
      fcitx5-chinese-addons
      fcitx5-gtk
    ];
  };
}
