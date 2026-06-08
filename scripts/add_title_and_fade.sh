#!/bin/bash
# Add title and fade-in to the first clip, fade-out to the last clip using VAAPI with progress and logging
set -euo pipefail

project_dir="$1"
clip_dir="$project_dir/output/cut_clips"
title_font="fonts/NotoSansJP-Bold.ttf"
subtitle_font="fonts/NotoSansJP-Regular.ttf"
fade_duration=1
log_file="$project_dir/output/add_title_and_fade.log"

config_file="$project_dir/config.sh"
if [[ ! -f "$config_file" ]]; then
  echo "config.sh not found in $project_dir" >&2
  exit 1
fi

source "$config_file"

main_title="${TITLE:-}"
subtitle="${SUBTITLE:-}"
if [[ -z "$main_title" ]]; then
  echo "TITLE is not set in $config_file" >&2
  exit 1
fi

mkdir -p "$project_dir/output"
> "$log_file"

mapfile -t clips < <(ls "$clip_dir"/*.mp4 2>/dev/null | sort)
if [[ ${#clips[@]} -eq 0 ]]; then
  echo "No clips in $clip_dir" >&2
  exit 1
fi
first_clip="${clips[0]}"
last_clip="${clips[-1]}"

# --- Title and fade-in on first clip ---
echo "Adding title and fade-in to: $(basename "$first_clip")"
ffmpeg -y -hide_banner \
  -i "$first_clip" \
  -vf "\
drawtext=fontfile=$title_font:text='$main_title':x=180:y=main_h-480:fontsize=140:fontcolor=white:alpha='if(lt(t,4),1, if(lt(t,5), 1-(t-4), 0))',\
drawtext=fontfile=$subtitle_font:text='$subtitle':x=180:y=main_h-300:fontsize=120:fontcolor=white:alpha='if(lt(t,4),1, if(lt(t,5), 1-(t-4), 0))',\
fade=t=in:st=0:d=$fade_duration" \
  -af "afade=t=in:st=0:d=$fade_duration" \
  -c:v h264_nvenc \
  -preset p6 \
  -rc vbr \
  -cq 18 \
  -b:v 0 \
  -profile:v high \
  -g 30 -bf 2 -refs 3 \
  -c:a pcm_s16be -ar 48000 -ac 2 \
  -movflags +faststart \
  -progress pipe:1 -stats \
  "${first_clip%.mp4}_titled.mp4" 2>> "$log_file" | \
while IFS='=' read -r key value; do
  if [[ "$key" == "out_time_ms" ]]; then
    seconds=$(echo "$value / 1000000" | bc -l)
    percent=$(echo "$seconds * 100 / 8" | bc -l)
    percent_int=$(printf "%.0f" "$percent")
    (( percent_int > 100 )) && percent_int=100
    filled=$((percent_int / 2))
    bar=$(printf "%0.s#" $(seq 1 $filled))
    space=$(printf "%0.s " $(seq 1 $((50 - filled))))
    printf "\r[Title] [%s%s] %3s%%" "$bar" "$space" "$percent_int"
  fi
done

mv "${first_clip%.mp4}_titled.mp4" "$first_clip"
echo -e "\nTitle and fade-in complete."

# --- Fade-out on last clip ---
echo "Adding fade-out to: $(basename "$last_clip")"
duration=$(ffprobe -v error -show_entries format=duration \
  -of default=noprint_wrappers=1:nokey=1 "$last_clip")
fade_start=$(echo "$duration - $fade_duration" | bc -l)
fade_start=$(printf "%.3f" "$fade_start")

ffmpeg -y -hide_banner \
  -i "$last_clip" \
  -vf "fade=t=out:st=$fade_start:d=$fade_duration" \
  -af "afade=t=out:st=$fade_start:d=$fade_duration" \
  -c:v h264_nvenc \
  -preset p6 \
  -rc vbr \
  -cq 18 \
  -b:v 0 \
  -profile:v high \
  -g 30 -bf 2 -refs 3 \
  -c:a pcm_s16be -ar 48000 -ac 2 \
  -movflags +faststart \
  -progress pipe:1 -stats \
  "${last_clip%.mp4}_faded.mp4" 2>> "$log_file" | \
while IFS='=' read -r key value; do
  if [[ "$key" == "out_time_ms" ]]; then
    seconds=$(echo "$value / 1000000" | bc -l)
    percent=$(echo "$seconds * 100 / $fade_duration" | bc -l)
    percent_int=$(printf "%.0f" "$percent")
    (( percent_int > 100 )) && percent_int=100
    filled=$((percent_int / 2))
    bar=$(printf "%0.s#" $(seq 1 $filled))
    space=$(printf "%0.s " $(seq 1 $((50 - filled))))
    printf "\r[Fadeout] [%s%s] %3s%%" "$bar" "$space" "$percent_int"
  fi
done

mv "${last_clip%.mp4}_faded.mp4" "$last_clip"
echo -e "\nFade-out complete."
