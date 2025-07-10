{
  pkgs,
  pkgs-unstable,
  ...
}: {
  home.packages =
    (with pkgs; [
      android-tools
      popsicle
      cdecl
    ])
    ++ (with pkgs-unstable; [
      imhex
      beekeeper-studio

      teams-for-linux
      obsidian
    ]);
}
