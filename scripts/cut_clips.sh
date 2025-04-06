#!/bin/bash
# Cut or link clips based on exclusion ranges in exclude.csv for a given project directory

project_dir="$1"
input_dir="$project_dir/input_clips"
output_dir="$project_dir/output/cut_clips"
exclude_file="$project_dir/exclude.csv"

mkdir -p "$output_dir"

for clip in $(ls "$input_dir"); do
  input="$input_dir/$clip"
  base="${clip%.*}"
  exclude_ranges=$(awk -F, -v c="$clip" '$1 == c { print $2 }' "$exclude_file")

  if [ -z "$exclude_ranges" ]; then
    # No exclusion → hard link the whole file
    ln "$input" "$output_dir/${base}_part0.mp4"
  else
    # Exclusion ranges exist → split and copy included segments
    duration=$(ffprobe -v error -show_entries format=duration \
      -of default=noprint_wrappers=1:nokey=1 "$input")
    last_end=0
    part_index=0
    IFS=';' read -ra ranges <<< "$exclude_ranges"
    for r in "${ranges[@]}"; do
      start=$(echo "$r" | cut -d'-' -f1)
      end=$(echo "$r" | cut -d'-' -f2)
      ffmpeg -y -i "$input" -ss "$last_end" -to "$start" -c copy \
        "$output_dir/${base}_part${part_index}.mp4"
      last_end="$end"
      part_index=$((part_index + 1))
    done
    # Extract the last segment after the final exclusion
    ffmpeg -y -i "$input" -ss "$last_end" -to "$duration" -c copy \
      "$output_dir/${base}_part${part_index}.mp4"
  fi
done
