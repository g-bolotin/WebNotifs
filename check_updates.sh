#!/bin/bash

# --- Configuration ---
PROJECT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
CONFIG_PATH="$PROJECT_DIR/.msmtprc"
MSMTP_BIN="$PROJECT_DIR/bin/msmtp-automated"
PLIST_NAME="com.gbolotin.webnotifs"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"

# --- Uninstall Handler --- 
if [ "$1" == "--uninstall" ]; then
    echo "Stopping and removing the launchd service..."
    
    # Unload the service first
    if launchctl list "$PLIST_NAME" &> /dev/null; then
        launchctl unload "$PLIST_PATH" || echo "Warning: Could not unload service."
    fi

    # Define files to clean up
    FILES_TO_REMOVE=("$PLIST_PATH" "$HASH_FILE")

    for FILE in "${FILES_TO_REMOVE[@]}"; do
        if [ -f "$FILE" ]; then
            if rm "$FILE"; then
                echo "Successfully removed: $(basename "$FILE")"
            else
                echo "ERROR: Failed to remove $FILE. Check permissions." >&2
                exit 1
            fi
        else
            echo "Note: $(basename "$FILE") was not found (already clean)."
        fi
    done

    echo "Cleanup complete."
    exit 0
fi

# --- Handle URL and Email ---
URL="$1"
EMAIL="$2"

if [[ -z "$URL" || -z "$EMAIL" ]]; then
    echo "Error: Missing required arguments."
    echo "Usage: $0 [URL] [EMAIL]"
    echo "Example: $0 \"https://sjsu.edu\" \"email@example.com\""
    exit 1
fi

# Sanitize URL for a unique, safe filename
SAFE_URL=$(echo "$URL" | sed 's/[^a-zA-Z0-9]/_/g')
HASH_FILE="$PROJECT_DIR/.hash_$SAFE_URL.txt"

# --- launchd Self Install ---
if [ ! -f "$PLIST_PATH" ]; then
    echo "First-time setup: Creating launchd service for $URL..."
    
    cat <<EOF > "$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_NAME</string>
    <key>ProgramArguments</key>
    <array>
        <string>$PROJECT_DIR/check_updates.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>3600</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$PROJECT_DIR/webnotifs.log</string>
    <key>StandardErrorPath</key>
    <string>$PROJECT_DIR/webnotifs.log</string>
</dict>
</plist>
EOF

    launchctl load "$PLIST_PATH"
    echo "Service loaded! Checking every hour."
fi

# --- Core ---
# Fetch content and hash it
CURRENT_HASH=$(curl -sL "$URL" | md5)

if [ -f "$HASH_FILE" ]; then
    OLD_HASH=$(cat "$HASH_FILE")

    if [ "$CURRENT_HASH" != "$OLD_HASH" ]; then
        
        # Send macOS System Notification
        osascript -e 'display notification "There has been an update to the CS 266 website." with title "WebNotifs" subtitle "Visit Website"'

        # Send Email via msmtp
        printf "Subject: Website Update\n\nThe site at $URL has changed." | "$MSMTP_BIN" -C "$CONFIG_PATH" "$EMAIL"

        # Update log file
        echo "$(date): Change detected and notification sent." >> "$PROJECT_DIR/webnotifs.log"
        
        # Update the hash file
        echo "$CURRENT_HASH" > "$HASH_FILE"

    else
        echo "$(date): No changes detected." >> "$PROJECT_DIR/webnotifs.log"
    fi
else
    echo "Initial run: Saving site fingerprint."
    echo "$CURRENT_HASH" > "$HASH_FILE"
fi