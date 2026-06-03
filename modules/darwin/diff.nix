{ pkgs, ... }:
{
  system.activationScripts.preActivation.text = ''
    incoming="''${systemConfig-}"
    if [[ -e /run/current-system && -e "''${incoming-}" ]]; then
      echo "--------------------------------------------------"
      echo "Comparing..."
      ${pkgs.nvd}/bin/nvd --nix-bin-dir=${pkgs.nix}/bin diff /run/current-system "''${incoming-}"
      echo "--------------------------------------------------"
    fi
  '';
}
