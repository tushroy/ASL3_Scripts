#!/bin/bash

# set your node number here where you want to run the script
NODE="#####"
TMPFILE="/tmp/msg"

MESSAGE=""
SAY_DATE=false
SAY_TIME=false

while getopts ":m:td" opt; do
  case $opt in
    m) MESSAGE="$OPTARG" ;;
    t) SAY_TIME=true ;;
    d) SAY_DATE=true ;;
    \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
    :) echo "Option -$OPTARG requires an argument." >&2; exit 1 ;;
  esac
done

TEXT=""

if $SAY_DATE; then
    TEXT+="Today is $(date '+%A %-d %B %Y'). "
fi

if $SAY_TIME; then
    TEXT+="Current time is $(date '+%I:%M %p'). "
fi

if [ -n "$MESSAGE" ]; then
    TEXT+="$MESSAGE"
fi

if [ -z "$TEXT" ]; then
    echo "Usage: $0 [-m \"message\"] [-d] [-t]"
    exit 1
fi

ORIG_PWD="$(pwd)"
cd /tmp || { echo "Failed to change to /tmp"; exit 1; }

sudo -u asterisk asl-tts -n $NODE -f $TMPFILE -t "$TEXT"
sudo -u asterisk asterisk -rx "rpt playback $NODE $TMPFILE"

cd "$ORIG_PWD"
