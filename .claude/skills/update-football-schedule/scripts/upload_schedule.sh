#!/usr/bin/env bash
# Overwrite schedule-football.json in the pfn-static S3 bucket with a local
# file, then re-download it and verify the bytes match what was uploaded.
#
# ONLY run this after the user has explicitly approved the final schedule
# table in-conversation. It overwrites the live object with no backup.
#
# Usage: upload_schedule.sh <local-json-path>
set -euo pipefail

SRC="${1:?usage: upload_schedule.sh <local-json-path>}"
BUCKET="pfn-static"
KEY="schedule-football.json"
REGION="us-east-2"

if [ ! -f "$SRC" ]; then
  echo "ERROR: source file not found: $SRC" >&2
  exit 1
fi

# Sanity check: must be valid JSON before we push it live.
if command -v jq >/dev/null 2>&1; then
  jq empty "$SRC" >/dev/null || { echo "ERROR: $SRC is not valid JSON" >&2; exit 1; }
fi

echo "Uploading $SRC -> s3://${BUCKET}/${KEY} ..."
aws s3 cp "$SRC" "s3://${BUCKET}/${KEY}" \
  --region "$REGION" \
  --content-type "application/json"

# Verify: re-download and compare.
VERIFY="$(mktemp)"
trap 'rm -f "$VERIFY"' EXIT
aws s3 cp "s3://${BUCKET}/${KEY}" "$VERIFY" --region "$REGION" >/dev/null

if cmp -s "$SRC" "$VERIFY"; then
  echo "VERIFIED: uploaded object matches local file."
else
  echo "WARNING: uploaded object does NOT match local file after re-download." >&2
  exit 1
fi
