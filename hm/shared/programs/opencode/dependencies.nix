{
  config,
  lib,
  pkgs,
  secrets,
  ...
}:
let
  opencode = config.programs.opencode;
in
{
  programs.jina.enable = lib.mkDefault opencode.enable;

  home.packages = lib.mkIf opencode.enable (
    with pkgs;
    [
      # below packages are already installed globally
      # - ast-grep
      # - httpie

      poppler-utils # pdftotext
    ]
  );
}
