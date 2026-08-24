#!/usr/bin/env bash
set -euo pipefail

skill_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
checkout="$skill_dir/checkout.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

assert_eq() {
  [[ "$1" == "$2" ]] || fail "expected '$2', got '$1'"
}

cache="$tmp/cache"
ssh_checkout="$cache/gitlab.example%3A27227/org/repo"
mkdir -p "$ssh_checkout"
git init -q "$ssh_checkout"
git -C "$ssh_checkout" remote add origin https://gitlab.example/org/repo.git
date +%s > "$ssh_checkout/.git/librarian-last-fetch"

path="$(LIBRARIAN_CACHE_ROOT="$cache" bash "$checkout" ssh://git@gitlab.example:27227/org/repo.git --path-only)"
assert_eq "$path" "$ssh_checkout"
assert_eq "$(git -C "$ssh_checkout" remote get-url origin)" "ssh://git@gitlab.example:27227/org/repo.git"

stale_checkout="$cache/github.com/org/missing"
mkdir -p "$stale_checkout"
git init -q "$stale_checkout"
git -C "$stale_checkout" remote add origin "$tmp/missing.git"

real_git="$(command -v git)"
fake_bin="$tmp/bin"
mkdir -p "$fake_bin"
cat > "$fake_bin/git" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"$TEST_STALE_CHECKOUT"* && "$*" == *" fetch "* ]]; then
  printf '%s\n' 'fatal: remote repository no longer exists' >&2
  exit 128
fi
exec "$TEST_REAL_GIT" "$@"
EOF
chmod +x "$fake_bin/git"

stdout="$tmp/stdout"
stderr="$tmp/stderr"
PATH="$fake_bin:$PATH" \
  TEST_REAL_GIT="$real_git" \
  TEST_STALE_CHECKOUT="$stale_checkout" \
  LIBRARIAN_CACHE_ROOT="$cache" \
  bash "$checkout" github.com/org/missing --force-update --path-only >"$stdout" 2>"$stderr"
assert_eq "$(<"$stdout")" "$stale_checkout"
grep -Fq 'LIBRARIAN_STALE' "$stderr" || fail "stale warning was not emitted"

network_checkout="$cache/127.0.0.1%3A1/org/network"
mkdir -p "$network_checkout"
git init -q "$network_checkout"
git -C "$network_checkout" remote add origin http://127.0.0.1:1/org/network.git
if LIBRARIAN_CACHE_ROOT="$cache" bash "$checkout" http://127.0.0.1:1/org/network --force-update --path-only >"$stdout" 2>"$stderr"; then
  fail "network failure was treated as a stale repository"
fi
if grep -Fq 'LIBRARIAN_STALE' "$stderr"; then
  fail "network failure emitted a stale repository warning"
fi

printf 'librarian tests passed\n'
