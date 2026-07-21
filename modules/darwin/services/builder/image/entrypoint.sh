#!/bin/sh
set -e

mkdir -p /run

fex="$(command -v FEX)"
test -x "$fex"

binfmt_dir=/proc/sys/fs/binfmt_misc
if [ ! -e "$binfmt_dir/register" ]; then
  mkdir -p "$binfmt_dir"
  mount -t binfmt_misc binfmt_misc "$binfmt_dir"
fi

if [ -e "$binfmt_dir/FEX-x86_64" ]; then
  printf '%s\n' -1 > "$binfmt_dir/FEX-x86_64"
fi
printf '%s\n' \
  ":FEX-x86_64:M:0:\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00:\xff\xff\xff\xff\xff\xfe\xfe\x00\x00\x00\x00\xff\xff\xff\xff\xff\xfe\xff\xff\xff:$fex:POCF" \
  > "$binfmt_dir/register"
grep -Fx "interpreter $fex" "$binfmt_dir/FEX-x86_64" >/dev/null
grep -Fx "flags: POCF" "$binfmt_dir/FEX-x86_64" >/dev/null

nix-daemon &
exec "$(which sshd)" -D -e
