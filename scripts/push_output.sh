#!/bin/bash
set -euo pipefail

project_dir="$1"
nas_path_file="$project_dir/nas_path.txt"

if [[ ! -f "$nas_path_file" ]]; then
  echo "nas_path.txt not found in $project_dir" >&2
  exit 1
fi

nas_path=$(< "$nas_path_file")
local_output_dir="$project_dir/output"
final_file="$local_output_dir/final.mp4"

if [[ ! -f "$final_file" ]]; then
  echo "Error: $final_file not found. Aborting push." >&2
  exit 1
fi

echo "Pushing to $nas_path..."

# ファイル一覧
files_to_copy=(
  "$final_file"
  "$project_dir/exclude.csv"
  "$project_dir/title.txt"
  "$project_dir/nas_path.txt"
)

# コピー
for file in "${files_to_copy[@]}"; do
  if [[ -f "$file" ]]; then
    echo "  Copying $(basename "$file")..."
    rsync -a --progress --no-perms "$file" "$nas_path"
  else
    echo "  Skipping $(basename "$file"): file not found"
  fi
done

echo "Push complete."
