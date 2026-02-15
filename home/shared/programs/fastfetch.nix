{ ... }:
{
  programs.fastfetch = {
    enable = true;
    settings = {
      logo = null;

      display = {
        separator = "";
        constants = [
          # constant {$1}
          # vertical bars at start and 46th characters forward and backward
          (
            "                                         "
            + "│${builtins.fromJSON ''"\u001b"''}[42D"
            + " ${builtins.fromJSON ''"\u001b"''}[39m"
          )
        ];
      };

      modules = [
        "break"
        {
          type = "custom";
          format = " ╭─────────────────────────────────────────────────────╮";
        }

        # fastfetch --help TYPE-format
        # https://github.com/fastfetch-cli/fastfetch/wiki/Format-String-Guide
        {
          type = "title";
          key = " {#39}│ {#32}Host{#}      {#31}>{#}";
          format = "{$1}  {user-name}@{host-name}";
        }
        {
          type = "os";
          key = " {#39}│ {#32}Distro{#}    {#31}>{#}";
          # show OS name/codename/version, or pretty-name if available
          format = "{$1}  {/pretty-name}{name} {codename} {version}{/}{?pretty-name}{pretty-name}{?}";
        }
        {
          type = "kernel";
          key = " {#39}│ {#32}Kernel{#}    {#31}>{#}";
          format = "{$1}  {sysname} {release} ({arch})";
        }
        {
          type = "packages";
          key = " {#39}│ {#32}Packages{#}  {#31}>{#}";
          format = "{$1}  {?nix-system}{nix-system} (nix-system){?}{?brew-cask}, {brew-cask} (brew-cask){?}";
        }
        {
          type = "terminal";
          key = " {#39}│ {#32}Terminal{#}  {#31}>{#}";
          format = "{$1}  {pretty-name} {?version}v{version}";
        }
        {
          type = "shell";
          key = " {#39}│ {#32}Shell{#}     {#31}>{#}";
          format = "{$1}  {pretty-name} v{version}";
        }
        {
          type = "cpu";
          key = " {#39}│ {#32}CPU{#}       {#31}>{#}";
          format = "{$1}  {name} ({cores-physical})";
        }
        {
          type = "memory";
          key = " {#39}│ {#32}Memory{#}    {#31}>{#}";
          format = "{$1}  {used} / {total}";
        }
        {
          type = "disk";
          key = " {#39}│ {#32}Disk{#}      {#31}>{#}";
          folders = "/";
          format = "{$1}  {size-used} / {size-total}";
        }
        {
          type = "uptime";
          key = " {#39}│ {#32}Uptime{#}    {#31}>{#}";
          format = "{$1}  {?days}{days}d {?}{?hours}{hours}h {?}{minutes}m";
        }

        {
          type = "custom";
          format = " ╰─────────────────────────────────────────────────────╯";
        }
      ];
    };
  };
}
