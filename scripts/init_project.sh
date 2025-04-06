#!/bin/bash
# Initialize a new cliplet project directory with sample input files

project_dir="$1"

if [ -z "$project_dir" ]; then
  echo "Usage: $0 <project_dir>"
  exit 1
fi

if [ -e "$project_dir/exclude.csv" ] || [ -e "$project_dir/title.txt" ]; then
  echo "Error: exclude.csv or title.txt already exists in $project_dir"
  exit 1
fi

mkdir -p "$project_dir/input_clips"

cat > "$project_dir/exclude.csv" <<EOF
clip,exclude_ranges
EOF

cat > "$project_dir/title.txt" <<EOF
Your Title Here
Your Subtitle Here
EOF

cat > "$project_dir/nas_path.txt" <<EOF
/path/to/nas/project_dir
EOF

echo "Initialized project at $project_dir"
