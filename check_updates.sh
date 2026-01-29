#!/bin/bash

# Working directory of script
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# --- Configuration ---
URL="https://www.cs.sjsu.edu/~melody/"
EMAIL="galit.bolotin@gmail.com"
HASH_FILE="$SCRIPT_DIR/.web_hash.txt"

# Fetch content and hash it
CURRENT_HASH=$(curl -sL "$URL" | md5)

if [ -f "$HASH_FILE" ]; then
    OLD_HASH=$(cat "$HASH_FILE")

    if [ "$CURRENT_HASH" != "$OLD_HASH" ]; then
        
        # Send macOS System Notification
        osascript -e 'display notification "There has been an update to the CS 266 website." with title "WebNotifs" subtitle "Visit Website"'

        # Send Email via msmtp
        printf "Subject: Website Update Detected\n\nThe website at $URL has been updated." | $SCRIPT_DIR/bin/msmtp-automated "$EMAIL"
        
        # Update the hash file
        echo "$CURRENT_HASH" > "$HASH_FILE"
    fi
else
    echo "Initial run: Saving site fingerprint."
    echo "$CURRENT_HASH" > "$HASH_FILE"
fi