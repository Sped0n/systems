{ ... }:
final: prev: {
  onlyoffice-desktopeditors = prev.onlyoffice-desktopeditors.override {
    gtk2 = null;
  };
}
