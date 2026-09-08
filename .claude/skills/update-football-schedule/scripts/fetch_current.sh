#!/usr/bin/env bash
# Download the current schedule-football.json from the pfn-static S3 bucket
# to a local path. Prints the destination path on success.
#
# Usage: fetch_current.sh <dest-path>
set -euo pipefail

DEST="${1:?usage: fetch_current.sh <dest-path>}"
BUCKET="pfn-static"
KEY="schedule-football.json"
REGION="us-east-2"

aws s3 cp "s3://${BUCKET}/${KEY}" "$DEST" --region "$REGION"
echo "$DEST"
