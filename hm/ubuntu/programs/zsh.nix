{ ... }:
{
  programs.zsh.initContent = ''
    sudo() {
      local executable
      if (( $# )) && [[ "$1" != -* ]]; then
        if executable="$(whence -p -- "$1")"; then
          shift
          command sudo -- "$executable" "$@"
          return
        fi
      fi
      command sudo "$@"
    }
  '';
}
