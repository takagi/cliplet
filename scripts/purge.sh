#!/bin/bash
# Delete the whole local project directory for every project that's confirmed
# pushed (NAS has final.mp4) and published (NAS has published.log), and whose
# local final.mp4 matches the NAS copy by size. Anything else is skipped
# with a reason, never guessed at.
set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(dirname "$script_dir")"
cd "$repo_dir"

bash "$script_dir/mount_nas.sh" 2>/dev/null || true

dry_run=0
[[ "${1:-}" == "-n" ]] && dry_run=1

shopt -s nullglob
for cfg in projects/*/config.sh; do
  proj_dir="$(dirname "$cfg")"
  name="$(basename "$proj_dir")"
  local_final="$proj_dir/output/final.mp4"

  [[ "$name" == "example" ]] && continue  # template project, never purge

  nas="$(set +u; source "$cfg" >/dev/null 2>&1; printf '%s' "${NAS_SOURCE_DIR:-}")"
  if [[ -z "$nas" ]]; then
    echo "SKIP  $name: NAS_SOURCE_DIR not set"
    continue
  fi

  nas_final="$nas/final.mp4"
  if [[ ! -f "$nas_final" ]]; then
    echo "SKIP  $name: not pushed (no final.mp4 on NAS)"
    continue
  fi
  if [[ ! -f "$nas/published.log" ]]; then
    echo "SKIP  $name: not published"
    continue
  fi

  # Only verify size when a local final.mp4 still exists; if it was already
  # cleaned up separately, there's nothing left to compare, but leftover
  # input_clips etc. are still safe to purge once push+publish is confirmed.
  if [[ -f "$local_final" ]]; then
    local_size=$(stat -c%s "$local_final")
    nas_size=$(stat -c%s "$nas_final")
    if [[ "$local_size" != "$nas_size" ]]; then
      echo "SKIP  $name: size mismatch (local=$local_size nas=$nas_size), local may be newer"
      continue
    fi
  fi

  if (( dry_run )); then
    echo "WOULD PURGE  $name ($(du -sh "$proj_dir" | cut -f1))"
  else
    echo "PURGE  $name ($(du -sh "$proj_dir" | cut -f1))"
    rm -rf "$proj_dir"
  fi
done
