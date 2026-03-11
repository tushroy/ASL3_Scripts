!/bin/bash
#
# Program: S21TIP Logger for ASL3
########################################################################

Prgm=$(basename $0)

# Exit if node number is zero
[ "$3" = "0" ] && exit

if [ "$1" == "" -o "$2" == "" -o "$3" == "" ]; then
	echo -e "\nERROR: missing required parameters."
	echo -e "\nUsage: $Prgm <1|0> <local node#> <remote node#>\a\n"
	exit
fi

PID=$$
INOUT="=v="
SMLTEMP=/tmp/SMLTEMP

function cleanup {
	rm -f ${SMLTEMP}.${PID}
}
trap cleanup EXIT

DATE=$(date '+%a %b %d %T %Z %Y')
DATE_UTC=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
LOGFILE=/etc/asterisk/node-connectlog.txt
NODESTATE_LOG=/etc/asterisk/node-currentnodes.txt
NODE_QUERY_DELAY=10
AUTO_STAT=0
NODELIST_URL="https://allmondb.allstarlink.org/allmondb.php"
NODELIST=/etc/asterisk/astdb.txt
MAX_AGE_HOURS=3 # configurable
MAX_AGE_SECONDS=$((MAX_AGE_HOURS * 3600))
MAX_LINES=3000
TRIM_MARGIN=1000 # keep last 50 lines after rotation

download_file() {
	wget -q -O "$NODELIST" "$NODELIST_URL"
}

if [ ! -f "$NODELIST" ]; then
	download_file
fi

# Get file modification time
FILE_TIME=$(stat -c %Y "$NODELIST")
CURRENT_TIME=$(date +%s)

AGE=$((CURRENT_TIME - FILE_TIME))

if [ "$AGE" -gt "$MAX_AGE_SECONDS" ]; then
	download_file
fi

# Acquire exclusive lock for concurrency
exec 200>>"$LOGFILE"
flock -n 200 || exit 1

# Rotate log if exceeds MAX_LINES
LINES=$(wc -l <"$LOGFILE")
if [ "$LINES" -ge "$MAX_LINES" ]; then
	BACKUP="$LOGFILE.$(date '+%Y%m%d-%H%M%S')"
	mv "$LOGFILE" "$BACKUP"
	# Keep last TRIM_MARGIN lines in new log
	tail -n $TRIM_MARGIN "$BACKUP" >"$LOGFILE"
fi

# Determine node type
TYPE=""
NODENO="$3"
COUNT=$(echo $3 | wc -m)
COUNT=$(($COUNT - 1))

# Check if remote node is numeric or callsign
if [ "$3" -eq "$3" ] 2>/dev/null; then
	TYPE=""
else
	TYPE="Callsign"
	# Differentiate clients:
	if [[ "$NODENO" =~ "-P" ]]; then
		ASTINFO="AllStar Phone Portal user"
	else
		ASTINFO="IaxRpt or Web Transceiver client"
	fi
fi

# Determine type by length
if [ "$TYPE" != "Callsign" -a "$COUNT" == 7 ]; then
	TYPE="EchoLink"
fi
if [ "$TYPE" != "Callsign" -a "$COUNT" == 3 ]; then
	TYPE="Extension"
fi

# AllStar node info from NODELIST
if [ "$TYPE" != "Callsign" -a "$TYPE" != "EchoLink" -a "$TYPE" != "IRLP" -a "$COUNT" -gt 3 ]; then
	TYPE="AllStar"
	NODENO=$3
	ASTINFO=$(cat $NODELIST | sed 's/\*//g' | grep ^$3"|" | sed 's/|/ /g' | sed 's/'$3'//')
fi

[ $3 == 0 ] && TYPE="AllStar" && ASTINFO=$(cat $NODELIST | sed 's/\*//g' | grep ^$3"|" | sed 's/|/ /g')

# Connection status
[ $1 == 0 ] && STATUS="DISCONNECTED"
[ $1 == 1 ] && STATUS="CONNECTED"

# Determine IN/OUT direction
if [ "$TYPE" = "EchoLink" ]; then
	chkINOUT=$(/usr/sbin/asterisk -rx "rpt lstats $2" | grep ^"$3 " | awk '{print $3}')
else
	chkINOUT=$(/usr/sbin/asterisk -rx "rpt lstats $2" | grep ^"$3 " | awk '{print $4}')
fi
[ "$chkINOUT" = "OUT" ] && INOUT="=OUT=>"
[ "$chkINOUT" = "IN" ] && INOUT="<=IN=="

# Display info
if [ "$TYPE" = "EchoLink" ]; then
	echo "EchoLink Info:" $STATUS $INOUT
elif [ "$TYPE" = "AllStar" ]; then
	echo "AllStar Info:" $STATUS $INOUT $3 $ASTINFO
elif [ "$TYPE" = "Extension" ]; then
	echo "Extension Info:" $STATUS $INOUT $3
fi

# Log to file
LOGINFO="$DATE_UTC | $2 | $TYPE | $3 | $ASTINFO | $INOUT | $STATUS"
echo $LOGINFO | sed 's/  */ /g' >>$LOGFILE

# Release lock
flock -u 200
trap - EXIT
cleanup

LOCKFILE="/tmp/s21tip-logger.lock"

# Try to get exclusive lock, exit if cannot
exec 201>"$LOCKFILE"
flock -n 201 || {
	echo "Script already running"
	exit 0
}

TMPNODEFILE="/tmp/rptnodes.$$"

sleep "$NODE_QUERY_DELAY"

while true; do
	/usr/sbin/asterisk -rx "rpt nodes $2" >"$TMPNODEFILE"

	{
		grep ',' "$TMPNODEFILE" | tr ',' ' ' | while read -ra NODES; do
			for NODE in "${NODES[@]}"; do

				NODE=$(echo "$NODE" | xargs)
				[ -z "$NODE" ] && continue

				MODE="Transceive"
				NODENO="$NODE"

				# Detect mode
				if [[ "$NODE" =~ ^R ]]; then
					MODE="Rx Only"
					NODENO="${NODE#R}"
				elif [[ "$NODE" =~ ^C ]]; then
					MODE="Monitor"
					NODENO="${NODE#C}"
				elif [[ "$NODE" =~ ^T ]]; then
					MODE="Transceive"
					NODENO="${NODE#T}"
				fi

				TYPE=""
				ASTINFO=""

				COUNT=$(echo "$NODENO" | wc -m)
				COUNT=$((COUNT - 1))

				if [ "$NODENO" -eq "$NODENO" ] 2>/dev/null; then
					TYPE=""
				else
					TYPE="Callsign"

					if [[ "$NODENO" =~ "-P" ]]; then
						ASTINFO="AllStar Phone Portal user"
					else
						ASTINFO="IaxRpt or Web Transceiver client"
					fi
				fi

				if [ "$TYPE" != "Callsign" -a "$COUNT" == 7 ]; then
					TYPE="EchoLink"
					NODENO_ECOLINK="${NODENO:1}"
					ASTINFO="EchoLink node $NODENO_ECOLINK"
				fi

				if [ "$TYPE" != "Callsign" -a "$COUNT" == 3 ]; then
					TYPE="Extension"
				fi

				if [ "$TYPE" != "Callsign" -a "$TYPE" != "EchoLink" -a "$COUNT" -gt 3 ]; then
					TYPE="AllStar"
					ASTINFO=$(sed 's/\*//g' "$NODELIST" | grep "^$NODENO|" | sed 's/|/ /g' | sed "s/$NODENO//")
				fi

				[ -z "$TYPE" ] && TYPE="AllStar"

				echo "$TYPE | $NODENO | $ASTINFO | $MODE"

			done
		done
	} >"$NODESTATE_LOG"

	rm -f "$TMPNODEFILE"

	if [ "$AUTO_STAT" -eq 0 ]; then
		flock -u 201
		exit 0
	fi

	sleep "$NODE_QUERY_DELAY"

done

exit 0
