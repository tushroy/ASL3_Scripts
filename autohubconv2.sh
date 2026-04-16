#!/bin/bash

FILE="/etc/asterisk/rpt.conf"
TARGET="startup_macro = *81367163"
ILINK_LINE="813 = ilink,13                    ; Permanently connect specified link -- transceive"

read -rp "Enter your personal node number: " NODE
read -rp "Want BD ASL Node 67163 connect on startup? (y/n): " ans

TMP_FILE=$(mktemp)

########################################
# 1. Handle startup_macro inside NODE
########################################
awk -v node="$NODE" -v target="$TARGET" -v ans="$ans" '
BEGIN {
    in_section=0
    added=0
}

/^\[.*\]/ {
    # If leaving section, add if missing
    if (in_section && !added) {
        if (ans ~ /^[Yy]/) print target
        else print ";startup_macro ="
        added=1
    }

    # Match [NODE](anything)
    if ($0 ~ "^\\[" node "\\]\\(") {
        in_section=1
        added=0
    } else {
        in_section=0
    }
}

{
    if (in_section && $0 ~ /^[; ]*startup_macro[ ]*=/) {
        if (ans ~ /^[Yy]/) print target
        else print ";startup_macro ="
        added=1
        next
    }

    print
}

END {
    if (in_section && !added) {
        if (ans ~ /^[Yy]/) print target
        else print ";startup_macro ="
    }
}
' "$FILE" > "$TMP_FILE"

mv "$TMP_FILE" "$FILE"

########################################
# 2. Handle ILINK globally (like before)
########################################
if [[ "$ans" =~ ^[Yy] ]]; then
    sed -i -E "s|^[; ]*813\s*=.*|$ILINK_LINE|" "$FILE"
else
    sed -i -E "s|^[; ]*813\s*=.*|; $ILINK_LINE|" "$FILE"
fi

########################################
# Done
########################################
if [[ "$ans" =~ ^[Yy] ]]; then
    echo "✔ Enabled: autolinking 67163 for node $NODE"
else
    echo "✖ Disabled: autolinking 67163 for node $NODE"
fi
