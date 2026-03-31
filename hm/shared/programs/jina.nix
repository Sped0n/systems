{
  config,
  functions,
  lib,
  pkgs,
  secrets,
  ...
}:
let
  jina = config.programs.jina;
in
{
  options.programs.jina.enable = lib.mkEnableOption "Whether to enable Jina CLI";

  config = lib.mkIf jina.enable {
    age.secrets = {
      "jina-api-key" = {
        file = "${secrets}/ages/jina-api-key.age";
        mode = "0400";
      };
    };

    home.packages = [
      (pkgs.writeShellScriptBin "jina" ''
        set -euo pipefail
        export JINA_API_KEY="$(${pkgs.coreutils}/bin/cat ${config.age.secrets."jina-api-key".path})"
        exec ${lib.getExe (pkgs.callPackage (functions.fromRoot "/packages/jina-cli.nix") { })} "$@"
      '')
    ];
  };
}
