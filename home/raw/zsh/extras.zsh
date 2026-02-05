zstyle ':completion:*' menu select
zvm_after_init_commands+=(eval "$(atuin init zsh --disable-up-arrow)")
