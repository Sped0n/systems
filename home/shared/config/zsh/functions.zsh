# codegpt
function ncodegpt() {
  local opts="commit --preview"
  # if we have any arguments, add --template_vars
  if [ $# -gt 1 ]; then
    opts+=" --template_vars"
  fi
  # parse
  zparseopts -E -D -- \
           -prefix:=o_prefix
    if [[ -v o_prefix[2] ]]; then
    # generate commit message with custom prefix
    opts+=" summarize_prefix="${o_prefix[2]}
  fi
  eval "codegpt $opts"
}

# yazi
function yz() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

