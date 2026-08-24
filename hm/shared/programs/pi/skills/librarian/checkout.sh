#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: checkout.sh <repo> [options]

Ensure a cached checkout exists at ~/.cache/checkouts/<host>/<org>/<repo>.

Options:
  --path-only                 Print only the checkout path.
  --force-update              Always fetch from origin and attempt fast-forward.
  --update-interval <secs>    Minimum seconds between updates (default: 300).

Environment:
  LIBRARIAN_CACHE_ROOT        Override cache root (default: ~/.cache/checkouts)
  LIBRARIAN_DEFAULT_HOST      Host for owner/repo shorthand (default: github.com)
  LIBRARIAN_UPDATE_INTERVAL   Default update interval in seconds
EOF
}

repo_input=""
path_only=0
force_update=0
update_interval="${LIBRARIAN_UPDATE_INTERVAL:-300}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path-only) path_only=1; shift ;;
    --force-update) force_update=1; shift ;;
    --update-interval)
      [[ $# -ge 2 ]] || { echo "error: --update-interval expects a value" >&2; exit 2; }
      update_interval="$2"
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *)
      [[ -z "$repo_input" ]] || { echo "error: unexpected argument: $1" >&2; exit 2; }
      repo_input="$1"
      shift
      ;;
  esac
done

[[ -n "$repo_input" ]] || { echo "error: repository is required" >&2; exit 2; }
[[ "$update_interval" =~ ^[0-9]+$ ]] || { echo "error: update interval must be a non-negative integer" >&2; exit 2; }

trim() {
  local value="$1"
  value="${value#${value%%[![:space:]]*}}"
  value="${value%${value##*[![:space:]]}}"
  printf '%s' "$value"
}

parsed_host=""
parsed_org=""
parsed_repo=""
parsed_origin=""

parse_repo() {
  local input authority first path scheme
  input="$(trim "$1")"
  input="${input%%\?*}"
  input="${input%%#*}"

  case "$input" in
    git@*:*)
      authority="${input%%:*}"
      parsed_host="${authority#git@}"
      path="${input#*:}"
      scheme="scp"
      ;;
    ssh://*)
      authority="${input#ssh://}"
      authority="${authority%%/*}"
      parsed_host="${authority#*@}"
      path="${input#ssh://$authority/}"
      scheme="ssh"
      ;;
    http://*|https://*)
      scheme="${input%%://*}"
      authority="${input#*://}"
      authority="${authority%%/*}"
      parsed_host="${authority#*@}"
      path="${input#*://$authority/}"
      ;;
    */*)
      first="${input%%/*}"
      if [[ "$first" == *.* || "$first" == localhost || "$first" == *:* ]]; then
        authority="$first"
        parsed_host="${authority#*@}"
        path="${input#*/}"
        scheme="https"
      else
        authority="${LIBRARIAN_DEFAULT_HOST:-github.com}"
        parsed_host="$authority"
        path="$input"
        scheme="https"
      fi
      ;;
    *) echo "error: unsupported repository format: $input" >&2; return 1 ;;
  esac

  path="${path#/}"
  path="${path%/}"
  IFS='/' read -r -a parts <<< "$path"
  if [[ ${#parts[@]} -ge 3 ]]; then
    case "${parts[2]}" in
      tree|blob|pull|issues|commit|actions|releases|compare|wiki) path="${parts[0]}/${parts[1]}" ;;
    esac
  fi
  path="${path%.git}"
  IFS='/' read -r -a parts <<< "$path"
  [[ ${#parts[@]} -ge 2 ]] || { echo "error: repository path must contain org/repo: $path" >&2; return 1; }

  local last_index=$(( ${#parts[@]} - 1 ))
  parsed_repo="${parts[$last_index]}"
  parsed_org="$(IFS='/'; printf '%s' "${parts[*]:0:$last_index}")"
  [[ -n "$parsed_host" && -n "$parsed_org" && -n "$parsed_repo" ]] || {
    echo "error: failed to parse repository: $input" >&2
    return 1
  }

  case "$scheme" in
    scp) parsed_origin="${authority}:${path}.git" ;;
    ssh) parsed_origin="ssh://${authority}/${path}.git" ;;
    http|https) parsed_origin="${scheme}://${authority}/${path}.git" ;;
  esac
}

parse_repo "$repo_input"

# Colons are valid on POSIX, but encoding the port makes cache paths portable.
cache_host="${parsed_host//:/%3A}"
cache_root="${LIBRARIAN_CACHE_ROOT:-$HOME/.cache/checkouts}"
checkout_path="$cache_root/$cache_host/$parsed_org/$parsed_repo"

mkdir -p "$(dirname "$checkout_path")"
if [[ ! -d "$checkout_path/.git" ]]; then
  git clone --filter=blob:none "$parsed_origin" "$checkout_path" >/dev/null
  clone_state="cloned"
else
  clone_state="existing"
fi

[[ -d "$checkout_path/.git" ]] || { echo "error: checkout path is not a git repository: $checkout_path" >&2; exit 3; }

if ! git -C "$checkout_path" remote get-url origin >/dev/null 2>&1; then
  git -C "$checkout_path" remote add origin "$parsed_origin"
fi
current_origin="$(git -C "$checkout_path" remote get-url origin 2>/dev/null || true)"
if [[ "$current_origin" != "$parsed_origin" ]]; then
  git -C "$checkout_path" remote set-url origin "$parsed_origin"
fi

is_missing_remote() {
  case "$1" in
    *"remote repository no longer exists"*) return 0 ;;
    *) return 1 ;;
  esac
}

last_fetch_file="$checkout_path/.git/librarian-last-fetch"
now_epoch="$(date +%s)"
needs_update=1
if [[ -f "$last_fetch_file" && "$force_update" -eq 0 ]]; then
  last_epoch="$(<"$last_fetch_file")"
  if [[ "$last_epoch" =~ ^[0-9]+$ ]] && (( now_epoch - last_epoch < update_interval )); then
    needs_update=0
  fi
fi

update_state="skipped"
ff_state="not-attempted"
if (( needs_update )); then
  if fetch_output="$(git -C "$checkout_path" fetch --prune --tags origin 2>&1)"; then
    printf '%s\n' "$now_epoch" > "$last_fetch_file"
    update_state="fetched"
    branch="$(git -C "$checkout_path" symbolic-ref --short -q HEAD 2>/dev/null || true)"
    upstream="$(git -C "$checkout_path" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
    dirty="$(git -C "$checkout_path" status --porcelain --untracked-files=no)"
    if [[ -n "$branch" && -n "$upstream" && -z "$dirty" ]]; then
      if git -C "$checkout_path" merge --ff-only "$upstream" >/dev/null 2>&1; then
        ff_state="fast-forwarded"
      else
        ff_state="skipped-non-ff"
      fi
    elif [[ -n "$dirty" ]]; then
      ff_state="skipped-dirty"
    else
      ff_state="skipped-no-upstream"
    fi
  else
    fetch_status=$?
    if (( path_only )) && is_missing_remote "$fetch_output"; then
      printf '%s\n' "$fetch_output" >&2
      printf 'warning: LIBRARIAN_STALE: origin reports this repository no longer exists; using cached checkout: %s\n' "$checkout_path" >&2
      printf '%s\n' "$checkout_path"
      exit 0
    fi
    printf '%s\n' "$fetch_output" >&2
    exit "$fetch_status"
  fi
fi

if (( path_only )); then
  printf '%s\n' "$checkout_path"
  exit 0
fi

cat <<EOF
repo: $parsed_host/$parsed_org/$parsed_repo
path: $checkout_path
state: $clone_state
update: $update_state
fast_forward: $ff_state
EOF
