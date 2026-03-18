#!/bin/bash

# Simple rpt_extnodes downloader with age check

finish() {
    return "$1" 2>/dev/null || exit "$1"
}

NODE_DB_HOST="snodes.allstarlink.org"
URI="diffnodes.php"
NODE_URL="http://${NODE_DB_HOST}/${URI}"

USERAGENT="asl3-update-nodelist/1.0"

FILEPATH="/etc/asterisk"
NODELIST="rpt_extnodes"
EXTNODES="${FILEPATH}/${NODELIST}"

MAX_AGE=$((3 * 3600))  # 3 hours

mkdir -p "$FILEPATH"

# Check file age
if [ -f "$EXTNODES" ]; then
    now=$(date +%s)
    file_time=$(stat -c %Y "$EXTNODES")
    age=$((now - file_time))

    if [ $age -lt $MAX_AGE ]; then
        echo "File is fresh (age: ${age}s), skipping download"
        return 0 2>/dev/null || exit 0
    fi
fi

TMPFILE=$(mktemp)

echo "Downloading file..."
wget --user-agent="$USERAGENT" -q -O "$TMPFILE" "$NODE_URL"

if [ $? -ne 0 ]; then
    echo "Download failed"
    rm -f "$TMPFILE"
    return 0 2>/dev/null || exit 0
fi

mv "$TMPFILE" "$EXTNODES"

chown asterisk:asterisk "$EXTNODES"
chmod 644 "$EXTNODES"

echo "Downloaded and updated $EXTNODES"

return 0 2>/dev/null || exit 0
