{lib, ...}: {
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      format = lib.concatStrings [
        "$all"
        "$fill"
        "$cmd_duration"
        "$line_break"
        "$character"
      ];
      command_timeout = 1000;
      fill = {
        symbol = " ";
      };
      directory = {
        truncate_to_repo = false;
        truncation_length = 0;
      };
      python = {
        symbol = "py";
        version_format = "$major.$minor.$patch";
        format = "via [$symbol($version )]($style)";
      };
      rust = {
        symbol = "rs";
        format = "via [$symbol($numver )]($style)";
      };
      package = {
        symbol = "pkg ";
        format = "is [$symbol$version]($style) ";
      };
      git_status = {
        ahead = "⇡$count";
        diverged = "⇕⇡$ahead_count⇣$behind_count";
        behind = "⇣$count";
      };
      git_metrics = {
        disabled = false;
      };
    };
  };
}
