#!/usr/bin/env bash
# On-demand aggregator for .specify/state/cache-metrics.jsonl.
# Usage:
#   bash .claude/hooks/cache-metrics-report.sh          # overall + per-skill + per-role
#   bash .claude/hooks/cache-metrics-report.sh tail 20  # last 20 rows, raw
#   bash .claude/hooks/cache-metrics-report.sh since 2026-04-24  # rows since date

set -euo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
LOG="${PROJECT_ROOT}/.specify/state/cache-metrics.jsonl"

if [[ ! -f "$LOG" ]]; then
  echo "No metrics log yet at: $LOG"
  echo "Run a few skills first; the Stop hook will populate it."
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required." >&2
  exit 1
fi

MODE="${1:-summary}"

case "$MODE" in
  tail)
    N="${2:-20}"
    tail -n "$N" "$LOG" | jq -c '{t:.timestamp, skill:.skill_name, role, story:.active_story_id, read:.cache_read, create:.cache_creation, input:.input_tokens}'
    ;;

  since)
    SINCE="${2:?usage: since YYYY-MM-DD}"
    jq -c --arg since "$SINCE" 'select(.timestamp >= $since)' "$LOG"
    ;;

  summary|*)
    echo "=== Cache Metrics Report ==="
    echo "Log: $LOG"
    echo "Rows: $(wc -l < "$LOG" | xargs)"
    echo

    # Overall hit rate = cache_read / (cache_read + cache_creation + input_tokens)
    echo "--- Overall ---"
    jq -s '
      (map(.cache_read)     | add // 0) as $r
      | (map(.cache_creation) | add // 0) as $c
      | (map(.input_tokens)   | add // 0) as $i
      | (map(.output_tokens)  | add // 0) as $o
      | {
          turns: length,
          cache_read: $r,
          cache_creation: $c,
          input_uncached: $i,
          output: $o,
          hit_rate_pct: (if ($r + $c + $i) > 0 then (100 * $r / ($r + $c + $i)) else 0 end | . * 10 | round / 10)
        }
    ' "$LOG"
    echo

    echo "--- By skill (top 15 by turn count) ---"
    jq -s '
      group_by(.skill_name)
      | map({
          skill: (.[0].skill_name // "(no skill)"),
          turns: length,
          read: (map(.cache_read) | add // 0),
          create: (map(.cache_creation) | add // 0),
          input: (map(.input_tokens) | add // 0),
          hit_rate_pct: (
            (map(.cache_read) | add // 0) as $r
            | (map(.cache_creation) | add // 0) as $c
            | (map(.input_tokens) | add // 0) as $i
            | (if ($r + $c + $i) > 0 then (100 * $r / ($r + $c + $i)) else 0 end | . * 10 | round / 10)
          )
        })
      | sort_by(-.turns)
      | .[:15]
    ' "$LOG"
    echo

    echo "--- By role ---"
    jq -s '
      group_by(.role)
      | map({
          role: (.[0].role // "(unset)"),
          turns: length,
          hit_rate_pct: (
            (map(.cache_read) | add // 0) as $r
            | (map(.cache_creation) | add // 0) as $c
            | (map(.input_tokens) | add // 0) as $i
            | (if ($r + $c + $i) > 0 then (100 * $r / ($r + $c + $i)) else 0 end | . * 10 | round / 10)
          )
        })
      | sort_by(-.turns)
    ' "$LOG"
    ;;
esac
