{ pkgs, ... }:
{
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  i18n.inputMethod = {
    enable = true;
    type = "ibus";
    # NOTE: User has to select rime or libpinyin as input method
    # in gnome settings (under keyboard).
    ibus.engines = with pkgs.ibus-engines; [
      libpinyin
      rime
    ];
  };
}
