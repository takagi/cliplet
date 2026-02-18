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
