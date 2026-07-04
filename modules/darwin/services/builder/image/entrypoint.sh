#!/bin/sh
set -e

mkdir -p /run
nix-daemon &
exec "$(which sshd)" -D -e
