#!/usr/bin/env bash
# Integration tests for ~/.config/rex/init.lua against the running Rex server.
# Run inside a Rex pane: bash ~/.config/rex/tests/integration.sh
# It opens a tab named rex-config-test in your session, sends key presses through
# Rex's client.key API (the same path the app uses), checks the results, and closes the tab.
set -u
: "${REX_SESSION:?run this inside a Rex pane}"
S="$REX_SESSION"
fails=0; count=0

json() { python3 -c "import json,sys; d=json.load(sys.stdin); print($1)"; }
check() { # name, got, want
  count=$((count + 1))
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$2', want '$3'"; fails=$((fails + 1)); fi
}
press() { # block, key-json, [prefix-json] -> prints handled
  local prefix=${3:-null}
  rex api call -s "$S" client.key "{\"block_id\":\"$1\",\"key\":$2,\"prefix\":$prefix}" | json 'd["handled"]'
}
split_of() { # block -> "<direction> first|second"
  rex api call -s "$S" session.view | python3 -c '
import json,sys; d=json.load(sys.stdin); b=sys.argv[1]
def find(n):
  s=n.get("split")
  if not s: return None
  if b in (s["before"].get("block_id"), s["after"].get("block_id")):
    return s["direction"]+" "+("first" if s["before"].get("block_id")==b else "second")
  return find(s["before"]) or find(s["after"])
for w in d["windows"]:
  for l in w["layers"]:
    r=find(l["layout"])
    if r: print(r); sys.exit()
print("none")' "$1"
}
foreground() { # block -> program name
  rex api call -s "$S" com.superlogical.terminal.process "{\"block_id\":\"$1\"}" | json 'd.get("foreground",{}).get("name","")'
}

SPACE='{"key":"space","mods":"","consumed_mods":"","text":" ","unshifted_codepoint":32,"composing":false,"action":"press"}'
CTRL_H='{"key":"key_h","mods":"ctrl","consumed_mods":"","text":"","unshifted_codepoint":104,"composing":false,"action":"press"}'

A=$(rex window new -s "$S" rex-config-test --json -- sh | json 'd["block_ids"][0]')
B=$(rex split -s "$S" -b "$A" --split=right --json -- sh | json 'd["block_ids"][0]')
trap 'rex block close "$A" >/dev/null 2>&1; rex block close "$B" >/dev/null 2>&1' EXIT

# ctrl+a then space: change split direction, from either pane
check "start side by side" "$(split_of "$A")" "horizontal first"
check "ctrl+a space is handled by Rex" "$(press "$A" "$SPACE" '["ctrl+a"]')" "True"
check "first pane: side by side -> stacked" "$(split_of "$A")" "vertical first"
press "$B" "$SPACE" '["ctrl+a"]' >/dev/null
check "second pane: stacked -> side by side" "$(split_of "$A")" "horizontal first"

# ctrl+h: focus left in a shell, pass through to Neovim
rex focus -s "$S" "$B" >/dev/null
check "ctrl+h in a shell is handled by Rex" "$(press "$B" "$CTRL_H")" "True"
check "ctrl+h in a shell moves focus left" \
  "$(rex api call -s "$S" session.view | json "[w['focused_block_id'] for w in d['windows'] if '$A' in json.dumps(w)][0]")" "$A"
rex send -s "$S" -b "$B" $'exec nvim --clean\n'
for _ in 1 2 3 4 5 6 7 8 9 10; do [ "$(foreground "$B")" = nvim ] && break; sleep 0.3; done
check "nvim started in test pane" "$(foreground "$B")" "nvim"
check "ctrl+h in Neovim passes through to Neovim" "$(press "$B" "$CTRL_H")" "False"

# extrakto: candidates come from the pane's screen
rex send -s "$S" -b "$A" $'echo zebra-marker-4821\n'; sleep 0.5
check "extrakto lists a word from the pane" \
  "$(~/.config/rex/bin/rex-extrakto "$S" "$A" --list | grep -c '^zebra-marker-4821$')" "1"

echo "$count checks, $fails failed"
exit $((fails > 0))
