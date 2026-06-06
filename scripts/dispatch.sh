#!/bin/bash
# Dispatch raw clips from a "動画回収YYYY-MM-DD" bucket into per-event folders.
#
# Workflow (two phases, driven by a mapping file):
#   Phase A: scan the bucket, group clips by capture date, write an editable
#            mapping TSV plus a per-date thumbnail contact sheet.
#   Phase B: re-run; clips are moved into Movies/<year>/<earliest-date> <event>/.
#
# Capture date/time come from each clip's embedded creation_time (the camera
# records this in UTC; we convert to local time). File mtime is only a fallback,
# because copying through the NAS can shift it by the timezone offset (~9h).
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(dirname "$script_dir")"
map_dir="$repo_dir/dispatch"

# Make sure the NAS is mounted before we touch it.
bash "$script_dir/mount_nas.sh"

# --- Resolve the dump directory --------------------------------------------
dump="${1:-}"
if [[ -z "$dump" ]]; then
  movies="$XDG_RUNTIME_DIR/gvfs/smb-share:server=synology,share=mtakagi/Movies"
  dump=$(ls -d "$movies"/動画回収* 2>/dev/null | fzf) || true
  if [[ -z "$dump" ]]; then
    echo "No bucket selected." >&2
    exit 1
  fi
fi
dump="${dump%/}"

if [[ ! -d "$dump" ]]; then
  echo "Bucket directory not found: $dump" >&2
  exit 1
fi

movies_dir="$(dirname "$dump")"
dump_name="$(basename "$dump")"
map_file="$map_dir/$dump_name.tsv"

# Collect the clips (camera files are *.MP4, no spaces).
mapfile -d '' -t files < <(find "$dump" -maxdepth 1 -type f -iname '*.MP4' -print0)
if [[ ${#files[@]} -eq 0 ]]; then
  echo "No .MP4 files in $dump" >&2
  exit 1
fi

# --- Capture date/time per clip (creation_time -> local; mtime fallback) ----
clip_stamp() {  # echoes "YYYY-MM-DD HH:MM"
  local f="$1" ct
  ct=$(ffprobe -v error -show_entries format_tags=creation_time \
    -of default=noprint_wrappers=1:nokey=1 "$f" 2>/dev/null)
  if [[ -n "$ct" ]] && date -d "$ct" +'%Y-%m-%d %H:%M' 2>/dev/null; then
    return
  fi
  date -r "$f" +'%Y-%m-%d %H:%M'
}

echo "Reading capture times for ${#files[@]} clips..."
declare -A FDATE FTIME
for f in "${files[@]}"; do
  stamp=$(clip_stamp "$f")
  FDATE[$f]="${stamp%% *}"
  FTIME[$f]="${stamp##* }"
done

# --- Thumbnails: one frame per clip, tiled into a per-date contact sheet -----
thumb_dir="$map_dir/thumbs/$dump_name"
if [[ ! -d "$thumb_dir" ]]; then
  echo "Generating thumbnails (one contact sheet per date)..."
  mkdir -p "$thumb_dir"
  declare -A DATE_FILES
  for f in "${files[@]}"; do
    DATE_FILES[${FDATE[$f]}]+="$f"$'\n'
  done
  for d in $(printf '%s\n' "${!DATE_FILES[@]}" | sort); do
    tmp=$(mktemp -d)
    n=0
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      n=$((n + 1))
      base=$(basename "${f%.*}")
      dur=$(ffprobe -v error -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 "$f" 2>/dev/null)
      mid=$(awk "BEGIN{x=$dur+0; printf \"%.2f\", (x>2 ? x/2 : 0)}")
      ffmpeg -nostdin -hide_banner -loglevel error -ss "$mid" -i "$f" \
        -frames:v 1 -vf "scale=480:-1" -y "$tmp/$base.jpg" 2>/dev/null || true
    done <<< "${DATE_FILES[$d]}"
    if ls "$tmp"/*.jpg >/dev/null 2>&1; then
      montage -label '%t' "$tmp"/*.jpg -tile 4x -geometry +6+6 \
        -title "$d ($n clips)" "$thumb_dir/$d.jpg" 2>/dev/null || true
      echo "  $d.jpg"
    fi
    rm -rf "$tmp"
  done
  echo "Thumbnails: $thumb_dir"
  echo
fi

# =============================================================================
# Phase A: generate the mapping if it does not exist yet.
# =============================================================================
if [[ ! -f "$map_file" ]]; then
  declare -A D_CNT D_BYTES D_TMIN D_TMAX
  for f in "${files[@]}"; do
    d="${FDATE[$f]}"
    t="${FTIME[$f]}"
    sz=$(stat -c %s "$f")
    D_CNT[$d]=$(( ${D_CNT[$d]:-0} + 1 ))
    D_BYTES[$d]=$(( ${D_BYTES[$d]:-0} + sz ))
    if [[ -z "${D_TMIN[$d]:-}" || "$t" < "${D_TMIN[$d]}" ]]; then D_TMIN[$d]="$t"; fi
    if [[ -z "${D_TMAX[$d]:-}" || "$t" > "${D_TMAX[$d]}" ]]; then D_TMAX[$d]="$t"; fi
  done

  mkdir -p "$map_dir"
  {
    echo "# Dispatch mapping for: $dump_name"
    echo "# Fill an event name after each '=>'. Same name on multiple lines merges"
    echo "# into one folder (prefixed with the earliest date). Blank = leave in place."
    echo "# Dates/times are each clip's creation_time in local time."
    echo "# Re-run this command to apply:  bash scripts/dispatch.sh \"$dump\""
    echo "#"
    echo "# date        count  size      time            => EVENT"
    while IFS= read -r d; do
      cnt=${D_CNT[$d]}
      size=$(numfmt --to=iec --suffix=B "${D_BYTES[$d]}")
      span="${D_TMIN[$d]}-${D_TMAX[$d]}"
      printf '%-12s  %-5s  %-8s  %-12s   => \n' "$d" "$cnt" "$size" "$span"
    done < <(printf '%s\n' "${!D_CNT[@]}" | sort)
  } > "$map_file"

  echo "Wrote mapping: $map_file"
  echo "Edit the EVENT column, then re-run to move the clips."
  exit 0
fi

# =============================================================================
# Phase B: apply an existing mapping.
# =============================================================================
declare -A EVENT_OF
while IFS= read -r line; do
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  [[ -z "${line//[[:space:]]/}" ]] && continue
  d=$(awk '{print $1}' <<<"$line")
  [[ "$d" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || continue
  event="${line#*=>}"
  event="$(sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' <<<"$event")"
  EVENT_OF[$d]="$event"
done < "$map_file"

# Build per-event stats from the actual files.
declare -A EV_CNT EV_EARLIEST
assigned=0
for f in "${files[@]}"; do
  d="${FDATE[$f]}"
  e="${EVENT_OF[$d]:-}"
  [[ -z "$e" ]] && continue
  assigned=$(( assigned + 1 ))
  EV_CNT[$e]=$(( ${EV_CNT[$e]:-0} + 1 ))
  if [[ -z "${EV_EARLIEST[$e]:-}" || "$d" < "${EV_EARLIEST[$e]}" ]]; then
    EV_EARLIEST[$e]="$d"
  fi
done

if [[ $assigned -eq 0 ]]; then
  echo "No event names filled in $map_file — nothing to move." >&2
  echo "Edit the EVENT column and re-run." >&2
  exit 1
fi

# Dry-run preview.
echo "Planned moves from: $dump"
echo
for e in "${!EV_CNT[@]}"; do
  earliest="${EV_EARLIEST[$e]}"
  year="${earliest:0:4}"
  printf '  %s clips -> %s/%s/%s %s/input_clips/\n' \
    "${EV_CNT[$e]}" "$movies_dir" "$year" "$earliest" "$e"
done | sort
echo
left=$(( ${#files[@]} - assigned ))
echo "($assigned of ${#files[@]} clips assigned; $left left in place)"
echo
read -r -p "Proceed with moving? [y/N] " ans
[[ "$ans" == "y" || "$ans" == "Y" ]] || { echo "Aborted."; exit 0; }

# Move.
for f in "${files[@]}"; do
  d="${FDATE[$f]}"
  e="${EVENT_OF[$d]:-}"
  [[ -z "$e" ]] && continue
  earliest="${EV_EARLIEST[$e]}"
  year="${earliest:0:4}"
  dest="$movies_dir/$year/$earliest $e/input_clips"
  mkdir -p "$dest"
  mv -n "$f" "$dest"/
done

echo "Dispatch complete."
