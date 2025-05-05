{...}: {
  programs.fastfetch = {
    enable = true;
    settings = {
      logo = null;

      display = {
        separator = "";
        constants = [
          # CONSTANT {$1} - VERTICAL BARS AT START AND 46th CHARACTERS FORWARD AND BACKWARD
          (
            "                                         "
            + "│${builtins.fromJSON ''"\u001b"''}[42D"
            + " ${builtins.fromJSON ''"\u001b"''}[39m"
          )
        ];
      };

      modules = [
        "break" # Start with a break

        # Top Border
        {
          type = "custom";
          format = " ╭─────────────────────────────────────────────────────╮";
        }

        # --- Modules ---
        # Key format: "│ {color}{Key Text}{#}{padding}{#red}>{#}"
        {
          type = "title";
          key = " {#39}│ {#32}Host{#}      {#31}>{#}";
          format = "{$1}  {1}@{2}";
        }
        {
          type = "os";
          key = " {#39}│ {#32}Distro{#}    {#31}>{#}";
          # If pretty name not applicable, fallbacks to Distro Name, Codename, Version ID
          format = "{$1}  {/3}{2} {10} {8}{/}{?3}{3}{?}";
        }
        {
          type = "kernel";
          key = " {#39}│ {#32}Kernel{#}    {#31}>{#}";
          format = "{$1}  {1} {2} ({4})"; # Corresponds to Sysname, Release, Architecture
        }
        {
          type = "packages";
          key = " {#39}│ {#32}Packages{#}  {#31}>{#}";
          format = "{$1}  {1} (nix-system)";
          # If you want to show counts from specific managers, you might need:
          # format = "{$1}  {?nix-system}{nix-system} (nix-system){?}"; # Adjust based on desired output
        }
        {
          type = "terminal";
          key = " {#39}│ {#32}Terminal{#}  {#31}>{#}";
          format = "{$1}  {5} {?6}v{6}"; # Corresponds to Process Name, Version
        }
        {
          type = "shell";
          key = " {#39}│ {#32}Shell{#}     {#31}>{#}";
          format = "{$1}  {6} v{4}"; # Corresponds to Name, Version
        }
        {
          type = "cpu";
          key = " {#39}│ {#32}CPU{#}       {#31}>{#}";
          format = "{$1}  {1} ({5})"; # Corresponds to Name, Core Count (physical)
        }
        {
          type = "memory";
          key = " {#39}│ {#32}Memory{#}    {#31}>{#}";
          format = "{$1}  {1} / {2}"; # Corresponds to Used, Total
        }
        {
          type = "disk";
          key = " {#39}│ {#32}Disk{#}      {#31}>{#}";
          folders = "/"; # Specify the folder to check
          format = "{$1}  {1} / {2}"; # Corresponds to Used, Total for the specified folder
        }
        {
          type = "uptime";
          key = " {#39}│ {#32}Uptime{#}    {#31}>{#}";
          # Using placeholders {0}, {1}, {2} for days, hours, minutes respectively
          format = "{$1}  {?1}{1}d {?}{?2}{2}h {?}{3}m";
        }

        # Bottom Border
        {
          type = "custom";
          format = " ╰─────────────────────────────────────────────────────╯";
        }
      ];
    };
  };
}
