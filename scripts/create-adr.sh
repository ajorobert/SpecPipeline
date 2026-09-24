#!/usr/bin/env bash
# create-adr.sh — reserve the next ADR file. Run from the project root.
#
#   bash {SCRIPTS_DIR}/create-adr.sh "<title>"
#
# Prints the created path, e.g. specs/adr/0028-outbox-for-integration-events.md.
# The number is one above the highest ADR number seen in specs/adr/ OR mentioned in its index, so the
# number of a deleted ADR is never reused. sk.adr writes the content and routes it in the index.

set -euo pipefail

TITLE="${1:?usage: create-adr.sh \"<title>\"}"
ADR_DIR="specs/adr"
INDEX="${ADR_DIR}/adr-index.md"

SLUG=$(printf '%s' "$TITLE" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')
[[ -n "$SLUG" ]] || { echo "ERROR: title has no usable characters" >&2; exit 1; }

mkdir -p "$ADR_DIR"
highest=$( { find "$ADR_DIR" -maxdepth 1 -type f -name '[0-9][0-9][0-9][0-9]-*.md' -exec basename {} \; ;
             [[ -f "$INDEX" ]] && grep -oE 'ADR-[0-9]{4}|[0-9]{4}-[a-z][a-z0-9-]*\.md' "$INDEX" | sed 's/^ADR-//'; } \
           | grep -oE '^[0-9]{4}' | sort -n | tail -1 || true)
NEXT=$(printf '%04d' $(( 10#${highest:-0} + 1 )))
FILENAME="${ADR_DIR}/${NEXT}-${SLUG}.md"

if [[ -e "$FILENAME" ]]; then
  echo "ERROR: $FILENAME already exists" >&2
  exit 1
fi
: > "$FILENAME"
printf '%s\n' "$FILENAME"
