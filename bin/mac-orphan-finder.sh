#!/usr/bin/env bash
#
# mac-orphan-finder.sh
# Diagnostic-only scan for orphaned data left behind by uninstalled apps.
#
# This script is READ-ONLY. It does not delete anything. It just identifies
# folders and files in ~/Library that have no matching installed app, so you
# can review and decide what to remove.
#
# Usage:
#   chmod +x mac-orphan-finder.sh
#   ./mac-orphan-finder.sh
#
# A copy of the report is also written to ~/mac-orphan-report.txt for later
# review.

set -u

REPORT="$HOME/mac-orphan-report.txt"
INDEX="/tmp/installed_bundles.txt"
CONTAINERS_LIST="/tmp/containers.txt"

# Tee everything to both stdout and the report file
exec > >(tee "$REPORT") 2>&1

echo "=========================================="
echo " Mac Orphan Finder"
echo " Run date: $(date)"
echo " Report saved to: $REPORT"
echo "=========================================="
echo ""
echo "This is a READ-ONLY scan. Nothing is deleted."
echo "Review the output and decide what to remove manually."
echo ""

# ----------------------------------------------------------------------------
# Step 1: Build an index of every installed app's bundle identifier
# ----------------------------------------------------------------------------
echo "=== Building installed app index ==="
{
  find /Applications -maxdepth 4 -name "*.app" -prune 2>/dev/null
  find "$HOME/Applications" -maxdepth 4 -name "*.app" -prune 2>/dev/null
  find /System/Applications -maxdepth 4 -name "*.app" -prune 2>/dev/null
  find /System/Library/CoreServices -maxdepth 3 -name "*.app" -prune 2>/dev/null
} | while IFS= read -r app; do
  defaults read "$app/Contents/Info" CFBundleIdentifier 2>/dev/null
done | sort -u > "$INDEX"

echo "Indexed $(wc -l < "$INDEX" | tr -d ' ') installed bundle identifiers"
echo ""

# ----------------------------------------------------------------------------
# Step 2: Orphaned Containers (sandboxed app data)
# ----------------------------------------------------------------------------
echo "=== Orphaned ~/Library/Containers (no matching installed app) ==="
echo "Format: SIZE  BUNDLE_ID"
echo ""
ls "$HOME/Library/Containers" 2>/dev/null | sort > "$CONTAINERS_LIST"
comm -23 "$CONTAINERS_LIST" "$INDEX" | while read -r bundle; do
  size=$(du -sh "$HOME/Library/Containers/$bundle" 2>/dev/null | cut -f1)
  printf "%-8s %s\n" "$size" "$bundle"
done | sort -hr | head -40
echo ""

# ----------------------------------------------------------------------------
# Step 3: Orphaned Group Containers (shared data between app and helpers)
# ----------------------------------------------------------------------------
echo "=== Orphaned ~/Library/Group Containers ==="
echo "Format: SIZE  GROUP_ID"
echo ""
ls "$HOME/Library/Group Containers" 2>/dev/null | while read -r group; do
  stripped="${group#group.}"
  if ! grep -q "^${stripped}" "$INDEX" 2>/dev/null && \
     ! grep -q "${stripped}$" "$INDEX" 2>/dev/null; then
    size=$(du -sh "$HOME/Library/Group Containers/$group" 2>/dev/null | cut -f1)
    printf "%-8s %s\n" "$size" "$group"
  fi
done | sort -hr | head -40
echo ""

# ----------------------------------------------------------------------------
# Step 4: Orphaned Saved Application State
# ----------------------------------------------------------------------------
echo "=== Orphaned ~/Library/Saved Application State ==="
echo "Format: SIZE  ENTRY"
echo ""
ls "$HOME/Library/Saved Application State" 2>/dev/null | while read -r entry; do
  bundle="${entry%.savedState}"
  if ! grep -qx "$bundle" "$INDEX"; then
    size=$(du -sh "$HOME/Library/Saved Application State/$entry" 2>/dev/null | cut -f1)
    printf "%-8s %s\n" "$size" "$entry"
  fi
done | sort -hr | head -40
echo ""

# ----------------------------------------------------------------------------
# Step 5: Orphaned Preferences (.plist files larger than 10 KB)
# ----------------------------------------------------------------------------
echo "=== Orphaned ~/Library/Preferences (>10 KB) ==="
echo "Format: SIZE  FILENAME"
echo ""
ls "$HOME/Library/Preferences"/*.plist 2>/dev/null | while read -r pref; do
  base=$(basename "$pref" .plist)
  if ! grep -qx "$base" "$INDEX"; then
    bytes=$(stat -f "%z" "$pref" 2>/dev/null || echo 0)
    if [ "$bytes" -gt 10000 ]; then
      size=$(du -h "$pref" 2>/dev/null | cut -f1)
      printf "%-8s %s\n" "$size" "$(basename "$pref")"
    fi
  fi
done | sort -hr | head -30
echo ""

# ----------------------------------------------------------------------------
# Step 6: Orphaned Caches (cache folders matching bundle-id naming)
# ----------------------------------------------------------------------------
echo "=== Orphaned ~/Library/Caches (bundle-id-style folders only) ==="
echo "Format: SIZE  FOLDER"
echo ""
ls "$HOME/Library/Caches" 2>/dev/null | while read -r cache; do
  # Only check folders that look like bundle IDs (contain dots)
  if [[ "$cache" == *.* ]] && ! grep -qx "$cache" "$INDEX"; then
    size=$(du -sh "$HOME/Library/Caches/$cache" 2>/dev/null | cut -f1)
    printf "%-8s %s\n" "$size" "$cache"
  fi
done | sort -hr | head -30
echo ""

# ----------------------------------------------------------------------------
# Step 7: Orphaned Logs (bundle-id-style folders only)
# ----------------------------------------------------------------------------
echo "=== Orphaned ~/Library/Logs (bundle-id-style folders only) ==="
echo "Format: SIZE  FOLDER"
echo ""
ls "$HOME/Library/Logs" 2>/dev/null | while read -r logdir; do
  if [[ "$logdir" == *.* ]] && ! grep -qx "$logdir" "$INDEX"; then
    size=$(du -sh "$HOME/Library/Logs/$logdir" 2>/dev/null | cut -f1)
    printf "%-8s %s\n" "$size" "$logdir"
  fi
done | sort -hr | head -30
echo ""

# ----------------------------------------------------------------------------
# Step 8: Orphaned LaunchAgents (login-time helpers from removed apps)
# ----------------------------------------------------------------------------
echo "=== Orphaned ~/Library/LaunchAgents ==="
echo "Format: FILENAME (these are tiny but indicate removed apps)"
echo ""
ls "$HOME/Library/LaunchAgents"/*.plist 2>/dev/null | while read -r agent; do
  base=$(basename "$agent" .plist)
  # LaunchAgent names are usually bundle IDs
  if ! grep -qx "$base" "$INDEX"; then
    echo "  $(basename "$agent")"
  fi
done | head -30
echo ""

# ----------------------------------------------------------------------------
# Step 9: Application Support (sorted by size, MANUAL review needed)
# ----------------------------------------------------------------------------
echo "=== ~/Library/Application Support (top 25 by size, manual review) ==="
echo "These folders use friendly names, not bundle IDs, so this script can't"
echo "auto-detect orphans. Eyeball this list and identify any apps you've"
echo "uninstalled."
echo ""
du -sh "$HOME/Library/Application Support"/* 2>/dev/null | sort -hr | head -25
echo ""

# ----------------------------------------------------------------------------
# Wrap up
# ----------------------------------------------------------------------------
echo "=========================================="
echo " Scan complete"
echo "=========================================="
echo ""
echo "Report saved to: $REPORT"
echo ""
echo "Next step: review the report, then ask Claude (or another trusted source)"
echo "before deleting anything. Some entries that look orphaned are actually"
echo "system services, helper apps, or shared data still in use."
