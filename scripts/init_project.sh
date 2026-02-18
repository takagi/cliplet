#!/bin/bash
# Initialize a new cliplet project directory with sample input files

project_dir="$1"

if [ -z "$project_dir" ]; then
  echo "Usage: $0 <project_dir>"
  exit 1
fi

if [ -e "$project_dir/config.sh" ]; then
  echo "Error: config.sh already exists in $project_dir"
  exit 1
fi

mkdir -p "$project_dir/input_clips"

cat > "$project_dir/config.sh" <<'EOF'
#!/bin/bash

# Project metadata
TITLE="Your Title Here"
SUBTITLE="Your Subtitle Here"

# NAS base directory containing input_clips/
NAS_SOURCE_DIR="/path/to/nas/project_dir"

# Optional exclusion ranges per clip (format: "start-end;start-end")
declare -A EXCLUDES=()
# EXCLUDES["C0001.mp4"]="12.5-18.2;30.0-42.0"
EOF

echo "Initialized project at $project_dir"
