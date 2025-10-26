{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [ nvd ];
  system.preSwitchChecks.update-diff = ''
    incoming="''${1-}"
    if [[ -e /run/current-system && -e "''${incoming-}" ]]; then
      echo "--------------------------------------------------"
      echo "Comparing..."
      ${pkgs.nvd}/bin/nvd --nix-bin-dir=${config.nix.package}/bin diff /run/current-system "''${incoming-}"
      echo "--------------------------------------------------"
    fi
  '';
}
