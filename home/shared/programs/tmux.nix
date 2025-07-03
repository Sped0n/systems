{pkgs, ...}: {
  programs.tmux = {
    enable = true;
    baseIndex = 1;
    clock24 = true;
    disableConfirmationPrompt = false;
    escapeTime = 10;
    historyLimit = 1024 * 100;
    keyMode = "vi";
    mouse = true;
    shell = "${pkgs.zsh}/bin/zsh";
    terminal = "tmux-256color";
    plugins = with pkgs.tmuxPlugins; [
      yank
      {
        plugin = resurrect;
        extraConfig = "set -g @resurrect-strategy-nvim 'session'";
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
        '';
      }
    ];
    extraConfig =
      ''
        # -- Remap Prefix ---------------------------------------------------------------
        unbind C-b
        set -g prefix C-a
        bind-key C-a send-prefix

        # -- Window Management ----------------------------------------------------------
        set -g renumber-windows on
        set -g allow-rename off
        bind c new-window -c '#{pane_current_path}'

        # -- Pane Management -----------------------------------------------------------
        bind b break-pane -d
        bind '\' split-window -h -c '#{pane_current_path}'
        bind - split-window -v -c '#{pane_current_path}'
        unbind '"'
        unbind %
        bind -n M-h select-pane -L
        bind -n M-l select-pane -R
        bind -n M-k select-pane -U
        bind -n M-j select-pane -D

        # -- Easy Reload ---------------------------------------------------------------
        bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded!"

        # -- Modifier Keys -------------------------------------------------------------
        set -s extended-keys off
        bind-key -T root C-\; send-keys Escape "[59;5u"
      ''
      + ''
        # -- General -------------------------------------------------------------------
        set -g status on                  # Turn the status bar on
        set -g status-interval 1          # Refresh status bar every 1 second
        set -g status-justify left        # Center the window list
        set -g status-position bottom     # Position the status bar at the bottom

        # -- Colors --------------------------------------------------------------------
        set -g status-style fg=white,bg=black
        setw -g window-status-current-style fg=black,bg=green
        setw -g window-status-style fg=white,bg=black

        # -- Pane Styling --------------------------------------------------------------
        set -g pane-border-style 'fg=green'
        set -g pane-active-border-style 'fg=green'

        # -- Content -------------------------------------------------------------------
        set -g status-left-length 20
        set -g status-left "[#{S}] " # Session name

        set -g status-right-length 40
        set -g status-right "#{H} | %Y-%m-%d | %H:%M " # Hostname, Date, Time

        setw -g window-status-format " #I:#W " # Inactive window format
        setw -g window-status-current-format " #I:#W#F " # Active window format with flags
      '';
  };
}
