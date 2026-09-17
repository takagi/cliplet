#!/bin/bash

# Auto-filled by 'make init' from the chosen NAS event folder.
# SUBTITLE is filled in by 'make pull' from the clip dates.
TITLE="Sports Day 2024"
SUBTITLE="2024.10.19"
NAS_SOURCE_DIR="/path/to/nas/mount/2024-10-19 Sports Day"

# Optional per-clip exclusion ranges (format: "start-end;start-end"); unused by default.
# Example: skip the first 5s and the 30-45s range of clip001.mp4:
# declare -A EXCLUDES=([clip001.mp4]="0-5;30-45")
declare -A EXCLUDES=()
