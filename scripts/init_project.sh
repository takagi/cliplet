#!/bin/bash
# Initialize a new cliplet project, auto-filling config.sh from a NAS event
# folder (the "<YYYY-MM-DD> <event>" folders that dispatch.sh produces). The
# project directory is named after the event unless a name is given explicitly.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Optional explicit project name/dir; otherwise derived from the chosen event.
project_arg="${1:-}"

# Pick the NAS event folder (override with NAS=... to skip the picker).
bash "$script_dir/mount_nas.sh"
movies="$XDG_RUNTIME_DIR/gvfs/smb-share:server=synology,share=mtakagi/Movies"

nas_dir="${NAS:-}"
if [[ -z "$nas_dir" ]]; then
  nas_dir=$(ls -dt "$movies"/*/*/ 2>/dev/null | fzf) || true
  if [[ -z "$nas_dir" ]]; then
    echo "No event folder selected." >&2
    exit 1
  fi
fi
nas_dir="${nas_dir%/}"

# TITLE from the folder name: "[【未編集】]YYYY-MM-DD <event>" -> "<event> <year>".
folder="$(basename "$nas_dir")"
folder="${folder#【未編集】}"        # drop the unedited marker if present
event="${folder#[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] }"
year="${folder:0:4}"
title="$event $year"

# Project directory: explicit arg wins, otherwise named after the event.
if [[ -z "$project_arg" ]]; then
  # Name the project "<event>_<YYYY-MM-DD>" so repeats of the same event
  # (e.g. multiple ズーラシア visits) never collide.
  project_dir="projects/${event}_${folder%% *}"
elif [[ "$project_arg" == */* ]]; then
  project_dir="$project_arg"
else
  project_dir="projects/$project_arg"
fi

if [ -e "$project_dir/config.sh" ]; then
  echo "Error: config.sh already exists in $project_dir"
  exit 1
fi

mkdir -p "$project_dir/input_clips"

cat > "$project_dir/config.sh" <<EOF
#!/bin/bash

# Auto-filled by 'make init' from the chosen NAS event folder.
# SUBTITLE is filled in by 'make pull' from the clip dates.
TITLE="$title"
SUBTITLE=""
NAS_SOURCE_DIR="$nas_dir"

# Optional per-clip exclusion ranges (format: "start-end;start-end"); unused by default.
declare -A EXCLUDES=()
EOF

# Human-readable summary on stderr; the project dir on stdout so callers
# (e.g. `make new`) can capture it.
echo "Initialized project at $project_dir" >&2
echo "  TITLE=$title" >&2
echo "  NAS_SOURCE_DIR=$nas_dir" >&2
echo "$project_dir"
