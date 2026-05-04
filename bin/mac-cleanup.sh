#!/usr/bin/env bash
#
# mac-cleanup.sh
# Safe monthly cleanup script for macOS.
# Everything in this script targets caches, regenerable build artifacts,
# and known update caches. No user data or app settings are touched.
#
# Usage:
#   chmod +x mac-cleanup.sh
#   ./mac-cleanup.sh
#
# You can also move this to ~/bin/mac-cleanup.sh and run it from anywhere
# once ~/bin is on your PATH.

set -u  # treat unset vars as errors, but don't exit on individual rm failures

echo "=== Mac cleanup starting ==="
echo "Free space before:"
df -h / | awk 'NR==1 || NR==2'
echo ""

before_avail=$(df -k / | awk 'NR==2 {print $4}')

run() {
  local label="$1"
  shift
  echo "-> $label"
  "$@" 2>/dev/null || true
}

# Xcode: device symbols and build artifacts (regenerated as needed)
run "Clearing iOS DeviceSupport"      rm -rf "$HOME/Library/Developer/Xcode/iOS DeviceSupport"/*
run "Clearing watchOS DeviceSupport"  rm -rf "$HOME/Library/Developer/Xcode/watchOS DeviceSupport"/*
run "Clearing tvOS DeviceSupport"     rm -rf "$HOME/Library/Developer/Xcode/tvOS DeviceSupport"/*
run "Clearing visionOS DeviceSupport" rm -rf "$HOME/Library/Developer/Xcode/visionOS DeviceSupport"/*
run "Clearing Xcode DerivedData"      rm -rf "$HOME/Library/Developer/Xcode/DerivedData"/*
run "Clearing CoreSimulator caches"   rm -rf "$HOME/Library/Developer/CoreSimulator/Caches"/*

# IDE / language / tool caches (all regenerable)
run "Clearing JetBrains cache"        rm -rf "$HOME/Library/Caches/JetBrains"/*
run "Clearing Google cache"           rm -rf "$HOME/Library/Caches/Google"/*
run "Clearing Firefox cache"          rm -rf "$HOME/Library/Caches/Firefox"/*
run "Clearing pip cache"              rm -rf "$HOME/Library/Caches/pip"/*
run "Clearing CocoaPods cache"        rm -rf "$HOME/Library/Caches/CocoaPods"/*
run "Clearing Playwright cache"       rm -rf "$HOME/Library/Caches/ms-playwright"/*
run "Clearing VSCode ShipIt cache"    rm -rf "$HOME/Library/Caches/com.microsoft.VSCode.ShipIt"/*
run "Clearing VSCodium ShipIt cache"  rm -rf "$HOME/Library/Caches/com.vscodium.ShipIt"/*
run "Clearing Signal ShipIt cache"    rm -rf "$HOME/Library/Caches/org.whispersystems.signal-desktop.ShipIt"/*
run "Clearing Plex caches"            rm -rf "$HOME/Library/Caches/PlexMediaServer"/* "$HOME/Library/Caches/Plex"/*
run "Clearing Apple Python cache"     rm -rf "$HOME/Library/Caches/com.apple.python"/*

# Autodesk: old update installer bundles (Fusion 360 re-fetches if needed)
run "Clearing Autodesk webdeploy"     rm -rf "$HOME/Library/Application Support/Autodesk/webdeploy"/*

# Homebrew: its own cleanup command is the right tool here
if command -v brew >/dev/null 2>&1; then
  echo "-> Running brew cleanup --prune=all"
  brew cleanup --prune=all || true
else
  echo "-> Skipping brew cleanup (brew not found)"
fi

echo ""
echo "=== Mac cleanup finished ==="
echo "Free space after:"
df -h / | awk 'NR==1 || NR==2'

after_avail=$(df -k / | awk 'NR==2 {print $4}')
recovered_kb=$(( after_avail - before_avail ))
recovered_mb=$(( recovered_kb / 1024 ))
recovered_gb=$(awk -v kb="$recovered_kb" 'BEGIN { printf "%.2f", kb/1024/1024 }')
echo ""
echo "Recovered this run: ${recovered_mb} MB (${recovered_gb} GB)"
