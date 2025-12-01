{ ... }:
{
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      line-number = true;
      dark = true;
      navigate = true;
      syntax-theme = "ansi";
      diff-so-fancy = true;
    };
  };
}
