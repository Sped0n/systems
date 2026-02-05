{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  secrets,
  vars,
  ...
}:
let
  opencode = config.programs.opencode;
in
{
  programs.opencode = {
    enable = lib.mkDefault false;
    package = pkgs-unstable.opencode;
  };

  xdg.configFile = lib.mkIf opencode.enable {
    "opencode/opencode.jsonc".source = (
      config.lib.file.mkOutOfStoreSymlink "${vars.home}/.config/systems/home/shared/config/opencode/config.jsonc"
    );
    "opencode/AGENTS.md".source = (
      config.lib.file.mkOutOfStoreSymlink "${vars.home}/.config/systems/home/shared/config/opencode/AGENTS.md"
    );
    "opencode/agents".source = (
      config.lib.file.mkOutOfStoreSymlink "${vars.home}/.config/systems/home/shared/config/opencode/agents"
    );
    "opencode/skills".source = (
      config.lib.file.mkOutOfStoreSymlink "${vars.home}/.config/systems/home/shared/config/opencode/skills"
    );
  };

  age.secrets = lib.mkIf opencode.enable {
    "openrouter-api-key" = {
      file = "${secrets}/ages/openrouter-api-key.age";
      mode = "0400";
    };
    "yescode-api-key" = {
      file = "${secrets}/ages/yescode-api-key.age";
      mode = "0400";
    };
    "jina-api-key" = {
      file = "${secrets}/ages/jina-api-key.age";
      mode = "0400";
    };
  };

  home.packages = lib.mkIf opencode.enable [
    (pkgs.writeShellScriptBin "oct" ''
      set -euo pipefail
      export OPENCODE_EXPERIMENTAL_MARKDOWN=1
      export OPENCODE_EXPERIMENTAL_PLAN_MODE=1
      export OPENROUTER_API_KEY="$(${pkgs.coreutils}/bin/cat ${
        config.age.secrets."openrouter-api-key".path
      })"
      export YESCODE_API_KEY="$(${pkgs.coreutils}/bin/cat ${config.age.secrets."yescode-api-key".path})"
      export JINA_API_KEY="$(${pkgs.coreutils}/bin/cat ${config.age.secrets."jina-api-key".path})"
      exec ${lib.getExe opencode.package} --port "$@"
    '')
    (pkgs.writeShellScriptBin "occ" ''
      set -euo pipefail
      export OPENROUTER_API_KEY="$(${pkgs.coreutils}/bin/cat ${
        config.age.secrets."openrouter-api-key".path
      })"
      export YESCODE_API_KEY="$(${pkgs.coreutils}/bin/cat ${config.age.secrets."yescode-api-key".path})"
      export JINA_API_KEY="$(${pkgs.coreutils}/bin/cat ${config.age.secrets."jina-api-key".path})"
      exec ${lib.getExe opencode.package} "$@"
    '')
  ];
}
