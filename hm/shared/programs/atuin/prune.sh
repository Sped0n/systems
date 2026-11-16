#!/usr/bin/env bash

preview=(--dry-run)
search_options=(--include-duplicates)
if [[ $# -eq 1 && $1 == --apply ]]; then
  preview=()
  search_options+=(--delete-it-all)
elif [[ $# -ne 0 ]]; then
  echo "Usage: atuin-prune [--apply]" >&2
  if [[ $# -eq 1 && $1 == --help ]]; then exit 0; fi
  exit 2
else
  echo "Preview only; use --apply to delete."
fi

before=$(date -u --date='90 days ago' +%Y-%m-%dT%H:%M:%SZ)
printf '\nFailed commands before %s:\n' "$before"
if output=$(env -u ATUIN_QUERY atuin search --filter-mode global --before "$before" --exclude-exit 0 "${search_options[@]}" 2>&1); then
  printf '%s\n' "$output"
else
  status=$?
  # Atuin returns 1 without output when no history matches the search.
  if [[ $status -ne 1 || -n $output ]]; then
    printf '%s\n' "$output" >&2
    exit "$status"
  fi
  echo "No matching failed commands."
fi

printf '\nDuplicates before %s (keep one per command/directory/host):\n' "$before"
atuin history dedup --before "$before" --dupkeep 1 "${preview[@]}"

printf '\nHistory matching configured exclusion filters (all ages):\n'
atuin history prune "${preview[@]}"
