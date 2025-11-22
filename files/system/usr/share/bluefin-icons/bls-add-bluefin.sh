#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

entries_dir="/boot/loader/entries"

for f in "$entries_dir"/ostree-*.conf "$entries_dir"/*-ostree-*.conf; do
  [ -f "$f" ] || continue

  # Already correct? skip
  if grep -qxE 'grub_class[[:space:]]+bluefin' "$f"; then
    continue
  fi

  tmp="$(mktemp)"
  if grep -qE '^grub_class[[:space:]]+' "$f"; then
    sed -E 's/^grub_class[[:space:]].*/grub_class bluefin/' "$f" >"$tmp"
  else
    awk '1; /^title[[:space:]]/{print "grub_class bluefin";}' "$f" >"$tmp"
  fi

  if ! cmp -s "$f" "$tmp"; then
    chmod --reference="$f" "$tmp"
    chown --reference="$f" "$tmp"
    command -v chcon >/dev/null 2>&1 && chcon --reference="$f" "$tmp" 2>/dev/null || true
    mv -f "$tmp" "$f"
  else
    rm -f "$tmp"
  fi
done
