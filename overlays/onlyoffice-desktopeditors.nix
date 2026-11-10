{ ... }:
final: prev: {
  onlyoffice-desktopeditors = prev.onlyoffice-desktopeditors.override (
    args:
    # Older nixpkgs still includes GTK2; newer versions have removed the argument.
    prev.lib.optionalAttrs (args ? gtk2) {
      gtk2 = null;
    }
  );
}
