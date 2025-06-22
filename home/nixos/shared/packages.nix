{pkgs, ...}: {
  imports = [
    ../../shared/packages.nix
  ];

  home.packages = with pkgs; [
    steam-run-free # for codeium language server
  ];
}
