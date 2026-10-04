{ pkgs-unstable, ... }:
{
  programs.brave = {
    enable = true;
    package = pkgs-unstable.brave;
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = [ "brave-browser.desktop" ];
      "x-scheme-handler/http" = [ "brave-browser.desktop" ];
      "x-scheme-handler/https" = [ "brave-browser.desktop" ];
      "x-scheme-handler/about" = [ "brave-browser.desktop" ];
      "x-scheme-handler/unknown" = [ "brave-browser.desktop" ];
    };
  };

  home.sessionVariables.BROWSER = "brave";
}
