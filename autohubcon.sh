#!/bin/bash

FILE="/etc/asterisk/rpt.conf"
TARGET="startup_macro = *81367163"
ILINK_LINE="813 = ilink,13                    ; Permanently connect specified link -- transceive"

read -rp "Want BD ASL Node 67163 connect of startup? (y/n): " ans

case "$ans" in
    [Yy]* )
        # Enable startup_macro
        sed -i -E "s|^[; ]*startup_macro\s*=.*|$TARGET|" "$FILE"

        # Enable ilink line (remove leading ;)
        sed -i -E "s|^[; ]*813\s*=.*|$ILINK_LINE|" "$FILE"

        echo "✔ Enabled: autolinking 67163"
        ;;

    [Nn]* )
        # Disable startup_macro
        sed -i -E "s|^[; ]*startup_macro\s*=.*|;startup_macro =|" "$FILE"

        # Disable ilink line (force leading ;)
        sed -i -E "s|^[; ]*813\s*=.*|; $ILINK_LINE|" "$FILE"

        echo "✖ Disabled: autolinking 67163"
        ;;

    * )
        echo "Invalid input. No changes made."
        ;;
esac
