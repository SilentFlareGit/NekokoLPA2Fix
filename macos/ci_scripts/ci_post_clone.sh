#!/bin/sh

# Fail on any error
set -e

# Forward to the ios script since the logic is identical and central
# We assume the directory structure is nlpa2/macos/ci_scripts -> ../../ios/ci_scripts/ci_post_clone.sh
# But locally we can just execute the commands or source it.

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
IOS_SCRIPT="$SCRIPT_DIR/../../ios/ci_scripts/ci_post_clone.sh"

if [ -f "$IOS_SCRIPT" ]; then
    echo "Delegating to iOS ci_post_clone.sh..."
    sh "$IOS_SCRIPT"
else
    echo "Error: Could not find shared script at $IOS_SCRIPT"
    exit 1
fi
