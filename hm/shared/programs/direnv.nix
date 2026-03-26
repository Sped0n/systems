{ pkgs-unstable, ... }:
{
  programs = {
    direnv = {
      enable = true;
      # TODO: direnv is broken on nixpkgs, and unstable merge the fix faster
      #       see https://nixpk.gs/pr-tracker.html?pr=502832
      package = pkgs-unstable.direnv;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };
    git.ignores = [ ".direnv" ];
  };
}
