#!/bin/bash
# Check summary info for the final output video

project_dir="$1"
output_file="$project_dir/output/final.mp4"

if [ ! -s "$output_file" ]; then
  echo "[ERROR] File not found or empty: $output_file"
  exit 1
fi

echo "===> Final video info ($output_file):"
echo ""
echo "---- Video ----"
mapfile -t video_info < <(ffprobe -v error -select_streams v:0 \
  -show_entries stream=codec_name,width,height,avg_frame_rate \
  -of default=noprint_wrappers=1:nokey=1 "$output_file")

# Extracting frame rate (average) and calculating the decimal value
frame_rate=$(echo "${video_info[3]}" | awk -F'/' '{print $1/$2}')

echo "Codec:  ${video_info[0]}"
echo "Size:   ${video_info[1]}x${video_info[2]} @ ${frame_rate} fps"

echo ""
echo "---- Audio ----"
mapfile -t audio_info < <(ffprobe -v error -select_streams a:0 \
  -show_entries stream=codec_name,channels \
  -of default=noprint_wrappers=1:nokey=1 "$output_file")

echo "Codec:    ${audio_info[0]}"
echo "Channels: ${audio_info[1]}"

echo ""
echo "---- File ----"
mapfile -t file_info < <(ffprobe -v error -show_entries format=duration,size,bit_rate \
  -of default=noprint_wrappers=1:nokey=1 "$output_file")

printf "Duration:  %.1f sec\n" "${file_info[0]}"
printf "Size:      %.1f MB\n"  "$((${file_info[1]} / 1048576))"
printf "Bitrate:   %.1f kbps\n" "$((${file_info[2]} / 1000))"
