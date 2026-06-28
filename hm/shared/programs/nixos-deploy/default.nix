{
  config,
  lib,
  pkgs,
  ...
}:
let
  nixos-deploy = config.programs.nixos-deploy;
in
{
  options.programs.nixos-deploy.enable = lib.mkEnableOption "nixos multi-host deploy helper";

  config = lib.mkIf nixos-deploy.enable {
    home.packages = [
      (pkgs.writeShellApplication {
        name = "nixos-deploy";
        runtimeInputs = with pkgs; [
          nixos-rebuild
          python3
        ];
        text = ''
          exec python3 ${./run.py} "$@"
        '';
      })
    ];
  };
}
