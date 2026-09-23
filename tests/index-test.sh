#!/bin/bash

# Build the index into a throwaway cache and check its shape.

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
export XDG_CACHE_HOME
XDG_CACHE_HOME=$(mktemp -d)
trap 'rm -rf "$XDG_CACHE_HOME"' EXIT

fail() { echo "index-test: $*" >&2; exit 1; }

if ! PATH="$HOME/.local/bin:$PATH" command -v gh >/dev/null; then
  echo "index-test: skipped (gh not installed)"
  exit 0
fi

index=$("$root/bin/gh-cheatsheet-index")

jq -e 'type == "array" and length > 50' <<<"$index" >/dev/null || fail "expected an array of commands"
jq -e 'all(.[]; has("category") and has("command") and has("description"))' <<<"$index" >/dev/null || fail "entries missing fields"
jq -e 'all(.[]; .command | startswith("gh "))' <<<"$index" >/dev/null || fail "commands must start with gh"
jq -e 'any(.[]; .command == "gh pr create" and .category == "Core")' <<<"$index" >/dev/null || fail "missing gh pr create"
jq -e 'any(.[]; .category == "GitHub Actions")' <<<"$index" >/dev/null || fail "missing GitHub Actions category"

order=$(jq -r '[.[].category] | reduce .[] as $c ([]; if index($c) then . else . + [$c] end) | join(",")' <<<"$index")
[[ $order == Core,GitHub\ Actions* ]] || fail "unexpected category order: $order"

ls "$XDG_CACHE_HOME"/io.github.bkbatchelor.omarchy-github-cli-cheatsheet/index-*.json >/dev/null || fail "cache not written"
[[ $("$root/bin/gh-cheatsheet-index") == "$index" ]] || fail "cached output differs"

echo "index-test: ok ($(jq length <<<"$index") commands; $order)"
