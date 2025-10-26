{
  determinate-nix-src,
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [ nvd ];
  system.activationScripts.preActivation.text = ''
    incoming="''${systemConfig-}"
    if [[ -e /run/current-system && -e "''${incoming-}" ]]; then
      echo "--------------------------------------------------"
      echo "Comparing..."
      ${pkgs.nvd}/bin/nvd --nix-bin-dir=${
        determinate-nix-src.packages."${pkgs.stdenv.system}".default
      }/bin diff /run/current-system "''${incoming-}"
      echo "--------------------------------------------------"
    fi
  '';
}
