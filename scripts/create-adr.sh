#!/usr/bin/env bash
# Usage: create-adr.sh <number> "<title>" [adr-dir]
# Creates a numbered ADR file in [adr-dir] (default: history/adr, or $SPECKIT_ADR_DIR).
# sk.adr passes the `adr_dir` value from .specify/project-config.md.

set -e

NUMBER=$(printf "%03d" "$1")
TITLE=$(echo "$2" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
ADR_DIR="${3:-${SPECKIT_ADR_DIR:-history/adr}}"
ADR_DIR="${ADR_DIR%/}"
FILENAME="${ADR_DIR}/ADR-${NUMBER}-${TITLE}.md"

if [ -f "$FILENAME" ]; then
  echo "ERROR: $FILENAME already exists"
  exit 1
fi

mkdir -p "$ADR_DIR"
touch "$FILENAME"
echo "Created: $FILENAME"
