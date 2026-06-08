#!/bin/bash
# Mark a project's NAS event folder as edited: drop the 【未編集】 prefix and
# update NAS_SOURCE_DIR in the project's config.sh so the link stays valid.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

bash "$script_dir/mount_nas.sh"

prefix="【未編集】"
src="${NAS_SOURCE_DIR%/}"
parent="$(dirname "$src")"
name="$(basename "$src")"

if [[ "$name" != "$prefix"* ]]; then
  echo "Already edited (no $prefix prefix): $name"
  exit 0
fi

dest="$parent/${name#"$prefix"}"

if [[ ! -d "$src" ]]; then
  echo "NAS folder not found: $src" >&2
  exit 1
fi
if [[ -e "$dest" ]]; then
  echo "Target already exists: $dest" >&2
  exit 1
fi

mv "$src" "$dest"

# Rewrite NAS_SOURCE_DIR in config.sh (avoids sed escaping issues with the path).
tmp="$(mktemp)"
while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" == NAS_SOURCE_DIR=* ]]; then
    printf 'NAS_SOURCE_DIR="%s"\n' "$dest"
  else
    printf '%s\n' "$line"
  fi
done < "$config_file" > "$tmp"
mv "$tmp" "$config_file"

echo "Marked edited: $(basename "$dest")"
echo "Updated NAS_SOURCE_DIR in $config_file"
