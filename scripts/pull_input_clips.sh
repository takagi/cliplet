#!/bin/bash
set -euo pipefail

project_dir="$1"
config_file="$project_dir/config.sh"

if [[ ! -f "$config_file" ]]; then
  echo "config.sh not found in $project_dir" >&2
  exit 1
fi

source "$config_file"

if [[ -z "${NAS_SOURCE_DIR:-}" ]]; then
  echo "NAS_SOURCE_DIR is not set in $config_file" >&2
  exit 1
fi

src="${NAS_SOURCE_DIR%/}/input_clips/"
dest="$project_dir/input_clips/"

if [ ! -d "$src" ]; then
  echo "Source directory $src does not exist." >&2
  exit 1
fi

echo "Copying from $src to $dest..."
mkdir -p "$dest"

rsync -a --progress "$src" "$dest"

echo "Pull complete."

# --- Fill SUBTITLE from the clip date span (only if still empty) -------------
# Each camera clip carries a creation_time (recorded in UTC; convert to local);
# file mtime is a fallback. SUBTITLE is "yyyy.mm.dd - yyyy.mm.dd" (a single
# date when all clips share one day).
clip_date() {  # echoes YYYY-MM-DD
  local f="$1" ct
  ct=$(ffprobe -v error -show_entries format_tags=creation_time \
    -of default=noprint_wrappers=1:nokey=1 "$f" 2>/dev/null)
  if [[ -n "$ct" ]] && date -d "$ct" +'%Y-%m-%d' 2>/dev/null; then
    return
  fi
  date -r "$f" +'%Y-%m-%d'
}

if [[ -z "${SUBTITLE:-}" ]]; then
  shopt -s nullglob nocaseglob
  clips=("$dest"*.mp4)
  shopt -u nullglob nocaseglob

  min_date="" max_date=""
  for f in "${clips[@]}"; do
    d=$(clip_date "$f")
    if [[ -z "$d" ]]; then continue; fi
    if [[ -z "$min_date" || "$d" < "$min_date" ]]; then min_date="$d"; fi
    if [[ -z "$max_date" || "$d" > "$max_date" ]]; then max_date="$d"; fi
  done

  if [[ -n "$min_date" ]]; then
    if [[ "$min_date" == "$max_date" ]]; then
      subtitle="${min_date//-/.}"
    else
      subtitle="${min_date//-/.} - ${max_date//-/.}"
    fi

    # Replace the SUBTITLE= line in config (append if it is missing).
    tmp=$(mktemp)
    found=0
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$line" == SUBTITLE=* ]]; then
        printf 'SUBTITLE="%s"\n' "$subtitle"
        found=1
      else
        printf '%s\n' "$line"
      fi
    done < "$config_file" > "$tmp"
    if [[ $found -eq 0 ]]; then
      printf 'SUBTITLE="%s"\n' "$subtitle" >> "$tmp"
    fi
    mv "$tmp" "$config_file"

    echo "SUBTITLE=$subtitle"
  fi
fi
