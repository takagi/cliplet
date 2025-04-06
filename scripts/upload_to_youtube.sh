#!/bin/bash
# Upload to YouTube via docker using .youtube-upload dir for secrets

project_dir="$1"
output_file="$project_dir/output/final.mp4"
title_file="$project_dir/title.txt"
secrets_dir=".youtube-upload"
docker_image="youtube-upload"

# Build the docker image (only if not already built)
echo "Building Docker image..."
docker build -t "$docker_image" submodules/youtube-upload || {
  echo "Failed to build Docker image"
  exit 1
}

# Read metadata
title=$(sed -n 1p "$title_file")
description=$(sed -n 2p "$title_file")

# Run upload via Docker
docker run --rm \
  -v "$(pwd)/$secrets_dir:/user/python/.youtube-upload" \
  -v "$(pwd)/$project_dir/output:/home/python/output" \
  "$docker_image" \
  --client-secrets /user/python/.youtube-upload/client_secrets.json \
  --credentials-file /user/python/.youtube-upload/credentials.json \
  --title "$title" \
  --description "$description" \
  --privacy private \
  /home/python/output/final.mp4
