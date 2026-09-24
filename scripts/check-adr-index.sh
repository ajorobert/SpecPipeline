#!/usr/bin/env bash
# check-adr-index.sh — the ADR drift guard. Run from the project root.
#
#   bash {SCRIPTS_DIR}/check-adr-index.sh
#
# Fails (exit 1) when
#   - an ADR file in specs/adr/ is not routed from specs/adr/adr-index.md, or
#   - the index routes to an ADR file that does not exist.
# An ADR file is `NNNN-kebab-title.md`; a route is any mention of such a file name in the index
# (a markdown link or a backticked path — the index is a router of signal blocks, not a table).
# Run by sk.adr after writing and by sk.verify; hosts may also run it in CI.

set -uo pipefail

ADR_DIR="specs/adr"
INDEX="${ADR_DIR}/adr-index.md"

if [[ ! -d "$ADR_DIR" ]]; then
  echo "check-adr-index: no ${ADR_DIR}/ — nothing to check"
  exit 0
fi
if [[ ! -f "$INDEX" ]]; then
  echo "check-adr-index: FAIL — ${INDEX} is missing but ${ADR_DIR}/ exists" >&2
  exit 1
fi

files=$(find "$ADR_DIR" -maxdepth 1 -type f -name '[0-9][0-9][0-9][0-9]-*.md' -exec basename {} \; | sort -u)
routes=$(grep -oE '[0-9]{4}-[A-Za-z0-9._-]+\.md' "$INDEX" | sort -u)

fail=0
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  if ! grep -qxF "$f" <<< "$routes"; then
    echo "  unrouted: ${ADR_DIR}/${f} — add it to the matching signal block(s) of ${INDEX}" >&2
    fail=1
  fi
done <<< "$files"
while IFS= read -r r; do
  [[ -z "$r" ]] && continue
  if [[ ! -f "${ADR_DIR}/${r}" ]]; then
    echo "  dangling: ${INDEX} routes to ${r}, which does not exist" >&2
    fail=1
  fi
done <<< "$routes"

if [[ "$fail" -ne 0 ]]; then
  echo "check-adr-index: FAIL" >&2
  exit 1
fi
echo "check-adr-index: PASS ($(grep -c . <<< "$files") ADRs, all routed)"
