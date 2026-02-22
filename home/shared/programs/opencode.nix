{
  config,
  lib,
  pkgs,
  secrets,
  vars,
  ...
}:
let
  opencode = config.programs.opencode;
in
{
  programs = {
    opencode = {
      enable = lib.mkDefault false;
      package = pkgs.llm-agents.opencode;
    };
    zsh.shellAliases = lib.mkIf opencode.enable {
      ocommit = "oc --agent commit-message-writer run \"STAGED CHANGE ONLY\" 2>/dev/null && git commit -e -F \"$(git rev-parse --git-path COMMIT_EDITMSG)\"";
    };
  };

  xdg.configFile = lib.mkIf opencode.enable {
    "opencode/opencode.jsonc".source = (
      config.lib.file.mkOutOfStoreSymlink "${vars.home}/.config/systems/home/raw/opencode/config.jsonc"
    );
    "opencode/AGENTS.md".source = (
      config.lib.file.mkOutOfStoreSymlink "${vars.home}/.config/systems/home/raw/opencode/AGENTS.md"
    );
    "opencode/agents".source = (
      config.lib.file.mkOutOfStoreSymlink "${vars.home}/.config/systems/home/raw/opencode/agents"
    );
    "opencode/skills".source = (
      config.lib.file.mkOutOfStoreSymlink "${vars.home}/.config/systems/home/raw/opencode/skills"
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
    (pkgs.writeShellScriptBin "oc" ''
      set -euo pipefail
      export OPENCODE_EXPERIMENTAL_MARKDOWN=1
      export OPENCODE_EXPERIMENTAL_PLAN_MODE=1
      export OPENROUTER_API_KEY="$(${pkgs.coreutils}/bin/cat ${
        config.age.secrets."openrouter-api-key".path
      })"
      export YESCODE_API_KEY="$(${pkgs.coreutils}/bin/cat ${config.age.secrets."yescode-api-key".path})"
      export JINA_API_KEY="$(${pkgs.coreutils}/bin/cat ${config.age.secrets."jina-api-key".path})"
      exec ${lib.getExe opencode.package} "$@"
    '')
  ];
}
