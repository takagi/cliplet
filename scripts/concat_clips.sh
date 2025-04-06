#!/bin/bash
# Concatenate clips and re-encode audio for YouTube compatibility with progress bar and logging

project_dir="$1"
clip_dir="$project_dir/output/cut_clips"
list_file="$project_dir/output/concat_list.txt"
output_file="$project_dir/output/final.mp4"
log_file="$project_dir/output/concat_clips.log"

mkdir -p "$project_dir/output"
> "$log_file"
rm -f "$list_file"

cd "$project_dir/output"
for f in cut_clips/*.mp4; do
  echo "file '$f'" >> concat_list.txt
done

# Calculate total duration of all clips
total_duration=0
for f in cut_clips/*.mp4; do
  dur=$(ffprobe -v error -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 "$f")
  total_duration=$(echo "$total_duration + $dur" | bc)
done
total_duration=$(printf "%.1f" "$total_duration")

# Start concatenation with progress tracking
ffmpeg -y -hide_banner -f concat -safe 0 -i concat_list.txt \
  -c:v copy -c:a aac -b:a 192k \
  -movflags +faststart \
  -progress pipe:1 -stats final.mp4 2>> concat_clips.log | \
while IFS='=' read -r key value; do
  if [[ "$key" == "out_time_ms" ]]; then
    seconds=$(echo "$value / 1000000" | bc -l)
    percent=$(echo "$seconds * 100 / $total_duration" | bc -l)
    percent_int=$(printf "%.0f" "$percent")
    (( percent_int > 100 )) && percent_int=100
    filled=$((percent_int / 2))
    if (( filled < 50 )); then
      space=$(printf "%0.s " $(seq 1 $((50 - filled))))
    else
      space=""
    fi
    bar=$(printf "%0.s#" $(seq 1 $filled))
    printf "\r[%s%s] %3s%%" "$bar" "$space" "$percent_int"
  fi
done

echo -e "\nConcatenation complete."
