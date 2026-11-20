#!/usr/bin/env bash
set -Eeuo pipefail

DATA_DIR="${DATA_DIR:-/data}"
BACKUP_DIR="$DATA_DIR/backups"
mkdir -p "$BACKUP_DIR"

if [[ $# -gt 1 ]]; then
  printf 'Usage: backup-data [destination.tar.gz]\n' >&2
  exit 2
fi

if [[ $# -eq 1 ]]; then
  output="$1"
else
  output="$BACKUP_DIR/valzzhost-$(date -u +%Y%m%d-%H%M%S).tar.gz"
fi

mkdir -p "$(dirname "$output")"
umask 077

tar -czf "$output" \
  --exclude='./backups' \
  -C "$DATA_DIR" \
  workspace projects .pm2 .npm-global users ssh .workspace_gid

chmod 0600 "$output"
printf 'Backup created: %s\n' "$output"
du -h "$output"
