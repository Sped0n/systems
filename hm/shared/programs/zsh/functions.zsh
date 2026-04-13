# yazi
function yz() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    builtin cd -- "$cwd" || exit
  fi
  rm -f -- "$tmp"
}

# Inject the GitHub token into Nix config for the current shell session.
function nix-bypass-gh-limit() {
  emulate -L zsh
  setopt pipefail no_unset

  local token line filtered current_config

  if ! command -v gh >/dev/null 2>&1; then
    print -u2 -- "gh not found in PATH"
    return 1
  fi

  if ! gh auth status >/dev/null 2>&1; then
    print -u2 -- "gh is not authenticated"
    return 1
  fi

  token="$(gh auth token)"
  current_config="${NIX_CONFIG-}"
  filtered=""

  while IFS= read -r line; do
    case "$line" in
    access-tokens\ =*) ;;
    *) filtered+="$line"$'\n' ;;
    esac
  done <<<"$current_config"

  export NIX_CONFIG="${filtered}access-tokens = github.com=${token}"
}
