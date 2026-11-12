{ ... }:
{
  programs.zsh.initContent = ''
    sudo() {
      local executable argument
      local -a sudo_options=()
      if [[ -n "''${TERMINFO:-}" ]]; then
        sudo_options=(--preserve-env=TERMINFO)
        for argument in "$@"; do
          # sudoedit rejects environment-preservation options.
          if [[ "$argument" == -e || "$argument" == --edit ]]; then
            sudo_options=()
            break
          fi
          if [[ "$argument" != -* && "$argument" != *=* ]]; then
            break
          fi
        done
      fi
      if (( $# )) && [[ "$1" != -* ]]; then
        if executable="$(whence -p -- "$1")"; then
          shift
          command sudo "''${sudo_options[@]}" -- "$executable" "$@"
          return
        fi
      fi
      command sudo "''${sudo_options[@]}" "$@"
    }
  '';
}
