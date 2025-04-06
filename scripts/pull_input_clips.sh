#!/bin/bash
set -euo pipefail

project_dir="$1"
nas_path_file="$project_dir/nas_path.txt"

if [[ ! -f "$nas_path_file" ]]; then
  echo "nas_path.txt not found in $project_dir" >&2
  exit 1
fi

nas_path=$(< "$nas_path_file")
src="$nas_path/input_clips/"
dest="$project_dir/input_clips/"

if [ ! -d "$src" ]; then
  echo "Source directory $src does not exist." >&2
  exit 1
fi

echo "Copying from $src to $dest..."
mkdir -p "$dest"

rsync -a --progress "$src" "$dest"

echo "Pull complete."
