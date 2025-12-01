{
  lib,
  pkgs-unstable,
  ...
}:
{
  programs.aichat = {
    enable = lib.mkDefault false;
    package = pkgs-unstable.aichat;
    settings = {
      model = lib.mkDefault "openai:x-ai/grok-4-fast";
      keybinding = "vi";
      highlight = true;
      light_theme = false;
      clients = [
        {
          type = "openai";
          api_base = "https://llmproxy.sped0n.com/openrouter/v1";
        }
      ];
      user_agent = "auto";
    };
  };
}
