{ pkgs, ... }:
let
  tmuxPaneSearcher = pkgs.writeShellScriptBin "tmux-pane-searcher" ''
    # 1. List all panes across all sessions.
    # Format: "Session:Win.Pane <tab> WindowName <tab> Command <tab> Path"
    # We use a distinct delimiter (tab) to make parsing easy.
    PANES=$(tmux list-panes -a -F "#{session_name}:#{window_index}.#{pane_index}	#{window_name}	#{pane_current_command}	#{pane_current_path}")

    # 2. Pipe to FZF
    # --delimiter: split input by tabs
    # --with-nth: show columns 1, 2, 3, 4 in the list
    # --preview: tell tmux to capture the content of the pane ID (column 1) and print it in color (-e)
    # --preview-window: put the preview on the right, taking 50% of space
    TARGET=$(echo "$PANES" | ${pkgs.fzf}/bin/fzf \
      --delimiter='\t' \
      --with-nth=1,2,3,4 \
      --header 'Session:Win.Pane | Name | Command | Path' \
      --preview 'tmux capture-pane -e -p -t {1}' \
      --preview-window='right:50%:wrap' \
      --reverse \
      --prompt 'Go to > ')

    if [[ -n "$TARGET" ]]; then
      # Extract the address (column 1) from the selected line
      TARGET_ADDRESS=$(echo "$TARGET" | cut -f1)
      
      # Switch client to that pane
      tmux switch-client -t "$TARGET_ADDRESS"
      
      # Also explicitly select the pane (sometimes switch-client just goes to the window)
      tmux select-pane -t "$TARGET_ADDRESS"
    fi
  '';
in
{
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
      {
        plugin = yank;
        extraConfig = ''
          set -g @yank_with_mouse off
        '';
      }
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-strategy-nvim 'session'
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
        '';
      }
    ];
    extraConfig = ''
      # --- Remap Prefix -----------------------------------------------------
      unbind C-b
      set -g prefix C-a
      bind-key C-a send-prefix

      # --- Window Management ------------------------------------------------
      set -g renumber-windows on
      set -g allow-rename off
      bind c new-window -c '#{pane_current_path}'

      # --- Pane Management --------------------------------------------------
      bind b break-pane -d
      bind '\' split-window -h -c '#{pane_current_path}'
      bind - split-window -v -c '#{pane_current_path}'
      unbind '"'
      unbind %
      bind h select-pane -L
      bind l select-pane -R
      bind k select-pane -U
      bind j select-pane -D

      # --- Easy Reload ------------------------------------------------------
      bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded!"

      # --- Floating Pane Searcher -------------------------------------------
      bind f display-popup -E -w 60% -h 70% "${tmuxPaneSearcher}/bin/tmux-pane-searcher"

      # --- Modifier Keys ----------------------------------------------------
      set -s extended-keys off
      bind-key -T root C-\; send-keys Escape "[59;5u"

      # --- VI ---------------------------------------------------------------
      unbind -T copy-mode-vi MouseDragEnd1Pane
      unbind -T copy-mode-vi v
      bind -T copy-mode-vi v send-keys -X begin-selection
    ''
    + ''
      # --- General ----------------------------------------------------------
      set -g status on                  # Turn the status bar on
      set -g status-interval 1          # Refresh status bar every 1 second
      set -g status-justify left        # Center the window list
      set -g status-position bottom     # Position the status bar at the bottom

      # --- Colors ------------------------------------------------------------
      set -g status-style fg=white,bg=black
      setw -g window-status-current-style fg=black,bg=green
      setw -g window-status-style fg=white,bg=black

      # --- Pane Styling -----------------------------------------------------
      set -g pane-border-style 'fg=green'
      set -g pane-active-border-style 'fg=green'

      # --- Content ----------------------------------------------------------
      set -g status-left-length 20
      set -g status-left "[#{S}] " # Session name

      set -g status-right-length 40
      set -g status-right "#{H} | %Y-%m-%d | %H:%M " # Hostname, Date, Time

      setw -g window-status-format " #I:#W " # Inactive window format
      setw -g window-status-current-format " #I:#W#F " # Active window format with flags
    '';
  };
}
