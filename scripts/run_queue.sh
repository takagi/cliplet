#!/bin/bash
# Run queued projects one at a time. Intended as a manual nightly kick:
# `make queue`.
#
# Each queue line is a project name (or projects/<name>); blank lines and lines
# starting with '#' are ignored. Each project runs the full `all` workflow
# (up to push; the YouTube upload is NOT run — do `make publish <name>` by hand).
# Output is kept (final.mp4 is needed for a later `make publish`); on success the
# entry is removed from the queue, on failure it stays for next time.
set -uo pipefail  # not -e: we must continue past a failing job

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(dirname "$script_dir")"
cd "$repo_dir"

queue_file="${1:-queue.txt}"
log_dir="logs"
mkdir -p "$log_dir"

if [[ ! -s "$queue_file" ]]; then
  echo "Queue is empty: $queue_file"
  exit 0
fi

mapfile -t entries < <(grep -vE '^[[:space:]]*(#|$)' "$queue_file")

declare -a done_list=() failed_list=()
for name in "${entries[@]}"; do
  name="$(sed -E 's/^[[:space:]]+|[[:space:]]+$//g' <<<"$name")"
  [[ -z "$name" ]] && continue
  case "$name" in */*) proj="$name";; *) proj="projects/$name";; esac

  log="$log_dir/$(basename "$proj")-$(date +%Y%m%d-%H%M%S).log"
  echo "[$(date +%H:%M:%S)] START $proj  (log: $log)"

  if make PROJECT="$proj" all >>"$log" 2>&1; then
    echo "[$(date +%H:%M:%S)] OK    $proj (output kept for publish)"
    done_list+=("$name")
  else
    echo "[$(date +%H:%M:%S)] FAIL  $proj (output kept; see $log)"
    failed_list+=("$name")
  fi
done

# Rewrite the queue with only the entries that failed (successes are removed).
if [[ ${#failed_list[@]} -gt 0 ]]; then
  printf '%s\n' "${failed_list[@]}" > "$queue_file"
else
  : > "$queue_file"
fi

echo
echo "Done: ${#done_list[@]}  Failed: ${#failed_list[@]}"
if [[ ${#failed_list[@]} -gt 0 ]]; then
  printf '  still queued (failed): %s\n' "${failed_list[@]}"
fi
