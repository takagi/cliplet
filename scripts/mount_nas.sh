#!/bin/bash
# Ensure the Synology SMB share is mounted via gvfs (idempotent, no root).
set -euo pipefail

share="smb://synology/mtakagi"

if gio mount -l 2>/dev/null | grep -q "$share/"; then
  exit 0
fi

echo "Mounting $share ..."
gio mount "$share"
