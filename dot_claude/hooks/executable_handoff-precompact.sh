#!/usr/bin/env bash
# Writes a handoff document just before Claude Code compacts the conversation.
#
# Wired up as a PreCompact hook in ~/.claude/settings.json. Claude Code sends
# this script a JSON object on standard input describing the session that is
# about to be compacted. We pull the conversation text out of the session
# transcript, hand it to a separate, cheap Claude run, and save the result
# under /tmp so the summary survives the compaction.
#
# Settings you can change with environment variables:
#   HANDOFF_MODEL     which model writes the summary   (default: sonnet)
#   HANDOFF_MAX_CHARS how much conversation to send    (default: 120000)
#   HANDOFF_OUT_DIR   where to save the document       (default: /tmp)
#   HANDOFF_DRY_RUN=1 extract the text but do not call Claude (for testing)
#
# Undo: remove the "PreCompact" block from ~/.claude/settings.json.

set -u

command -v jq >/dev/null 2>&1 || exit 0

payload=$(cat)
transcript=$(printf '%s' "$payload" | jq -r '.transcript_path // empty' 2>/dev/null)
session=$(printf '%s' "$payload" | jq -r '.session_id // "unknown"' 2>/dev/null)
trigger=$(printf '%s' "$payload" | jq -r '.trigger // .matcher // "unknown"' 2>/dev/null)
workdir=$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)

[ -n "$transcript" ] && [ -f "$transcript" ] || exit 0

model=${HANDOFF_MODEL:-sonnet}
max_chars=${HANDOFF_MAX_CHARS:-120000}
out_dir=${HANDOFF_OUT_DIR:-/tmp}
label=$(basename "${workdir:-$PWD}")
out="$out_dir/claude-handoff-$(date +%Y%m%d-%H%M%S)-$label.md"

# Flatten the transcript into readable text: one labelled block per message,
# keeping only the text parts (tool call payloads are dropped, they are bulky
# and the summary does not need them).
conversation=$(jq -r '
  select(.message != null)
  | (.message.role // .type // "?") as $role
  | (
      if (.message.content | type) == "string" then .message.content
      else [ .message.content[]? | select(.type == "text") | .text ] | join("\n")
      end
    ) as $text
  | select($text != null and ($text | length) > 0)
  | "### " + $role + "\n" + $text
' "$transcript" 2>/dev/null | tail -c "$max_chars" | sed -n '/^### /,$p')

[ -n "$conversation" ] || exit 0

if [ "${HANDOFF_DRY_RUN:-0}" = "1" ]; then
  printf '%s\n' "$conversation" > "$out"
  printf 'dry run: extracted %s characters to %s\n' "$(printf '%s' "$conversation" | wc -c | tr -d ' ')" "$out"
  exit 0
fi

instructions="You are reading the tail of a Claude Code session transcript that is about to be \
compacted, which means most of it is about to be discarded. Write a handoff document in Markdown \
so a fresh agent can pick the work up with no other context.

Cover, using plain literal language and no metaphors: what the work is; what has already been done \
and verified; what is applied but not yet confirmed working; decisions taken and the reason for \
each; every file touched, named by full path with a plain description of what it is and what \
changed; commands that proved useful; anything known to be unverified or uncertain; and the single \
next step. Name files and commands exactly. Do not invent anything that is not in the transcript. \
Redact any credentials, tokens or personal identifiers. Output only the Markdown document."

{
  printf '<!-- session %s | trigger %s | transcript %s | written %s -->\n\n' \
    "$session" "$trigger" "$transcript" "$(date '+%Y-%m-%d %H:%M:%S')"
  printf '%s' "$conversation" | claude -p \
    --model "$model" \
    --settings '{"disableAllHooks":true}' \
    "$instructions" 2>/dev/null
} > "$out"

exit 0
