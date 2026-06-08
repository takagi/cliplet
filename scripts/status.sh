#!/bin/bash
# Show each project's processing status, derived from artifacts so it works no
# matter how the work was run (make queue, make new, or step by step).
#
#   EDITED    - NAS event folder no longer prefixed with 【未編集】
#   BUILT     - final.mp4 present in the NAS event folder (pushed)
#   PUBLISHED - published.log present in the NAS event folder
#   QUEUED    - still listed in queue.txt
set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(dirname "$script_dir")"
cd "$repo_dir"

bash "$script_dir/mount_nas.sh" 2>/dev/null || true

queue_file="queue.txt"
in_queue() { [[ -f "$queue_file" ]] && grep -qxF "$1" "$queue_file" 2>/dev/null; }

# PROJECT is last because full-width (CJK) names break fixed-width alignment;
# the ASCII status columns before it stay aligned regardless of the name.
fmt='%-7s  %-6s  %-10s  %-7s  %s\n'
# shellcheck disable=SC2059
printf "$fmt" EDITED BUILT PUBLISHED QUEUED PROJECT
# shellcheck disable=SC2059
printf "$fmt" ------ ----- --------- ------ -------

shopt -s nullglob
found=0
for cfg in projects/*/config.sh; do
  found=1
  proj_dir="$(dirname "$cfg")"
  name="$(basename "$proj_dir")"
  # Read NAS_SOURCE_DIR from the project config without leaking into our shell.
  nas="$(set +u; source "$cfg" >/dev/null 2>&1; printf '%s' "${NAS_SOURCE_DIR:-}")"

  edited="?"; built="-"; published="-"
  if [[ -n "$nas" ]]; then
    case "$(basename "$nas")" in 【未編集】*) edited="no";; *) edited="yes";; esac
    [[ -f "$nas/final.mp4" ]] && built="yes" || built="no"
    [[ -f "$nas/published.log" ]] && published="yes" || published="no"
  fi
  q="-"; in_queue "$proj_dir" && q="yes"

  # shellcheck disable=SC2059
  printf "$fmt" "$edited" "$built" "$published" "$q" "$name"
done

if [[ $found -eq 0 ]]; then
  echo "(no projects under projects/)"
fi
