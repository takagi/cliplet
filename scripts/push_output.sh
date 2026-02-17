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

nas_path="$NAS_SOURCE_DIR"
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
  "$project_dir/config.sh"
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
