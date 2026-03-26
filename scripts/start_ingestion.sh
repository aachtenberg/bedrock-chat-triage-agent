#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <knowledge-base-id> <data-source-id>"
  exit 1
fi

aws bedrock-agent start-ingestion-job \
  --knowledge-base-id "$1" \
  --data-source-id "$2"
