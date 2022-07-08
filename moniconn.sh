#!/usr/bin/env bash
#
# Monitor internet and wifi connectivity and collect time series data.
#
# Run moniconn.sh in a separate window or in the background for as long
# as you want.
#
# You can then check moniconn.csv (CSV) to get a record of the loss of
# service.
#
# A typical usage would be to start ./moniconn.sh and then check
# moniconn.csv every day. Kill the moniconn.sh run after a week or so.
#
# You can run gnuplot or some other tool view the results.
#
# Environment Variables
#   START=time    Start time, default: now.
#                 Set START='17:00' to start a 5:00pm
#                 Set START='23:59' to start a 11:59pm
#                 Set START='10 minutes' to start in 10 minutes.
#   STOP=cond     STOP condition. default: None (runs forever) or until ctrl-c is entered.
#                 Set STOP='1 minute' to stop after a minute.
#                 Set STOP='2 minutes' to stop after two minutes.
#                 Set STOP='1 day' to stop after a day.
#                 Set STOP='2 days' to stop after two days.
#                 Set STOP='1 week' to stop after a week.
#                 Set STOP='2 weeks' to stop after two weeks.
#   CSV=file      CSV data file, default: moniconn.csv.
#   CI=secs       capture interval, defauLt=300 (5min)
#   SI=secs       sample interval (must be factor of CI that is less than CI), default=5
#                 SI should be less than the total processing time of the loop commands.
#   PING=cmd      ping command. Default "ping -t 1 -c 1".
#   INTERNET_URL  the URL used to test internet connectivity, default www.google.com
#   WIFI_IP       the IP address used to test wifi connetivity, default is deduced using ifconfig.
#   VERBOSE=0     no output, all data is in the data (CSV) file.
#   VERBOSE=1     output only when a capture record is generated
#   VERBOSE=2     VERBOSE=1 + report connection errors
#   VERBOSE=3     VERBOSE=2 + sample status
#   VERBOSE=4     VERBOSE=3 + debug messages
#
# Try to figure out the default wifi ip address.
# The user can override it by setting WIFI_IP=... manually.
WIFI_IP_=$(ifconfig | \
               grep 'inet ' | \
               grep -v '127.0.0.1' | \
               awk '{print $2}'  | \
               sed -E 's/\.[0-9]+$/.1/' | \
               head -1 2>/dev/null)

: "${CSV=moniconn.csv}"
: "${SI:=5}"
: "${CI:=300}"
: "${INTERNET_URL:=www.google.com}"
: "${WIFI_IP:=$WIFI_IP_}"
: "${PING:=ping -t 1 -c 1}"
: "${STOP:=}"
: "${START:=}"
: "${VERBOSE:=0}"

# error message
function _err {
    printf '\x1b[31;1mERROR:%s: %s\x1b[0m\n' "$1" "$2"
}

# debug message
function _debug {
    printf '\x1b[35;1mDEBUG:%s: %s\x1b[0m\n' "$1" "$2"
}

# info message
function _info {
    printf '\x1b[34;1mINFO:%s: %s\x1b[0m\n' "$1" "$2"
}

# pause until boundary it reached
function pause_until {
    local INTERVAL
    local SEC  # avoid shellcheck warning
    # trim off the leading zero
    INTERVAL="$1"
    SEC=$(date +%s)
    local REM=$(( SEC % INTERVAL ))
    local SLEEP_TIME=$(( INTERVAL - REM ))
    if (( VERBOSE >= 4 )) ; then
        _debug "$LINENO" "$SEC % $INTERVAL => $REM : sleep $SLEEP_TIME"
    fi
    sleep $SLEEP_TIME
}

# write to csv data file
function csv_write {
    local CSV_LINE="$2"
        echo "$CSV_LINE" >> "$CSV"
        if (( VERBOSE >=1 )) ; then
            echo "$CSV_LINE"
        fi
}

# report settings
function settings {
    printf '\x1b[34;1m'
    cat <<EOF
Settings
   Start Date                : $START_DATE
   Start Condition (START)   : "$START"
   Stop Date                 : $STOP_DATE
   Stop Condition (STOP)     : "$STOP"
   Capture Data File (CSV)   : $CSV
   Capture Interval (CI)     : $CI seconds
   Sample Interval (SI)      : $SI seconds
   Samples Per Capture (SBC) : $SPC
   Verbosity Level (VERBOSE) : $VERBOSE
EOF
    printf '\x1b[0m\n'
}

# report summary information
function summary {
    local CURR_DATE  # disable shellcheck warning
    CURR_DATE=$(date --iso-8601=second)
    printf '\x1b[34;1m'
    cat <<EOF

Summary
   Current Date                     : $CURR_DATE
   Start Date                       : $START_DATE
   Start Condition (START)          : "$START"
   Stop Date                        : $STOP_DATE
   Stop Condition (STOP)            : "$STOP"
   Capture Data File (CSV)          : $CSV
   Capture Interval (CI)            : $CI seconds
   Sample Count                     : $SC
   Sample Interval (SI)             : $SI seconds
   Sample Success Count             : $SSC
   Sample Success Duration          : $SSD seconds
   Sample Wifi Error Count          : $SEWC
   Sample Wifi Error Duration       : $SEWD seconds
   Sample Internet Error Count      : $SEIC
   Sample Internet Error Duration   : $SEID seconds
   Samples Per Capture (SBC)        : $SPC
   Captured Successful Records      : $CSC
   Captured Successful Duration     : $CSD
   Captured Wifi Error Records      : $CEWC
   Captured Wifi Error Duration     : $CEWD
   Captured Internet Error Records  : $CEIC
   Captured Internet Error Duration : $CEID
   Verbosity Level (VERBOSE)        : $VERBOSE
EOF
    printf '\x1b[0m\n'
}

# ctrlc handler
function ctrlc {
    summary
    read -r -t 30 -n 1 -p 'Continue (Y/n)? ' confirm
    if ! echo "$confirm" | grep -q '^[Yy]\?$' ; then
        exit 0
    fi
    echo ""
}

# main
if (( CI < SI )) ; then
    _err $LINENO "capture interval ($CI) must be larger than the sample interval ($SI)"
    exit 1
fi

if (( ( CI % SI ) > 0 )) ; then
    _err $LINENO "sampling ($SI)  and capture ($CI)  intervals do not overlap"
    exit 1
fi

# wait until the correct start condition
START_DATE=$(date --iso-8601=second)
STOP_DATE=''
STOP_DATE_SEC=0

if [ -n "$START" ] ; then
    START_DATE=$(date -d "$START" --iso-8601=second)
    START_DATE_SLEEP_SEC=$(( $(date -d "$START" +'%s') - $(date +'%s') ))
    if (( $(date -d "$START" +'%s') < $(date +'%s') )) ; then
        _info $LINENO "NOW    : $(date +'%s') $(date --iso-8601=second)"
        _info $LINENO "START  : $(date -d "$START" +'%s') $(date -d "$START" --iso-8601=second)"
        _err "$LINENO" "START earlier than NOW"
        exit 1
    fi
fi

if [ -n "$STOP" ] ; then
    if echo "$STOP" | grep -q -E '(-|:)' ; then
        # Handle explicit STOP dates like STOP=9:30
        STOP_DATE=$(date -d "$STOP" --iso-8601=second)
        STOP_DATE_SEC=$(date -d "$STOP" +'%s')
    else
        STOP_DATE=$(date -d "$START_DATE + $STOP" --iso-8601=second)
        STOP_DATE_SEC=$(date -d "$START_DATE + $STOP" +'%s')
    fi
    if [ -n "$START" ] ; then
        START_DATE_SEC=$(date -d "$START" +'%s')
        if (( STOP_DATE_SEC < START_DATE_SEC )) ; then
            _info "$LINENO" "STOP_DATE  : $STOP_DATE"
            _info "$LINENO" "START_DATE : $START_DATE"
            _info "$LINENO" "STOP_DATE_SEC  : $STOP_DATE_SEC"
            _info "$LINENO" "START_DATE_SEC : $START_DATE_SEC"
            _err "$LINENO" "STOP earlier than START"
            exit 1
        fi
    fi
fi

# Initialize loop variables
SPC=$(( CI / SI ))

# display the settings
settings

# wait until stat condition is met
if (( START_DATE_SLEEP_SEC )) ; then
    if (( VERBOSE )) ; then
        _info "$LINENO" "waiting $START_DATE_SLEEP_SEC seconds for start condition ($START): $START_DATE"
    fi
    sleep $START_DATE_SLEEP_SEC
fi

# wait until capture boundary to start
if (( VERBOSE )) ; then
    SLEEP_TIME=$(( CI - ($(date +%s) % CI ) ))
    _info "$LINENO" "waiting for capture the $CI second interval boundary ($SLEEP_TIME seconds)"
fi
pause_until "$CI"

SC=0    # sample count
SEWC=0  # sample error wifi count
SEWD=0  # sample error wifi duration
SEIC=0  # sample error internet count
SEID=0  # sample error internet duration
SSC=0   # sample success count
SSD=0   # sample success duration
CEWC=0
CEWD=0
CEIC=0
CEID=0
CSC=0
CSD=0
if [ ! -f "$CSV" ] ; then
    csv_write $LINENO "type,timestamp,ssc,ssd,sewc,sewd,seic,seid"
fi
trap ctrlc INT
trap ":" ALRM

SDTS=$(date +%s)
while true ; do
    SC=$(( SC + 1 ))
    if ! $PING "$INTERNET_URL" >/tmp/moniconn-internet-ping.log 2>&1 ; then
        if ! $PING "$WIFI_IP" >/tmp/moniconn-wifi-ping.log 2>&1 ; then
            # sample error wifi count and duration
            if (( VERBOSE >= 2 )) ; then
                _err "$LINENO" "$SC / $SPC: wifi connection error detected at $(date --iso-8601=second)"
            fi
            SEWC=$(( SEWC + 1 ))
            SEWD=$(( SEWD + $(date +%s) - SDTS ))
            CEWC=$(( CEWC + 1 ))
            CEWD=$(( CEWD + SEWD ))
        else
            # sample error internet count and duration
            if (( VERBOSE >= 2 )) ; then
                _err "$LINENO" "$SC / $SPC: internet connection error detected at $(date --iso-8601=second)"
            fi
            SEIC=$(( SEWC + 1 ))
            SEID=$(( SEID + $(date +%s) - SDTS ))
            CEIC=$(( CEIC + 1 ))
            CEID=$(( CEID + SEID ))
        fi
    else
        if (( VERBOSE >= 3 )) ; then
            _info "$LINENO" "$SC / $SPC: successful connection at $(date --iso-8601=second)"
        fi
        # sample success internet count and duration
        SSC=$(( SSC + 1 ))
        SSD=$(( SSD + $(date +%s) - SDTS ))
        CSC=$(( CEIC + 1 ))
        CSD=$(( CEID + SEID ))
    fi
    SDTS=$(date +%s)
    pause_until "$SI"
    if (( SC == SPC )) ; then
        CDTS=$(date --iso-8601=second)
        # Report sample data for capture interval
        csv_write $LINENO "count,$CDTS,$SSC,$SSD,$SEWC,$SEWD,$SEIC,$SEID"
        SEWC=0
        SEWD=0
        SEIC=0
        SEID=0
        SSC=0
        SSD=0
        SC=0
        if (( STOP_DATE_SEC > 0 )) ; then
            CURR_DATE_SEC=$(date '+%s')
            if (( CURR_DATE_SEC >= STOP_DATE_SEC )) ; then
                break
            fi
        fi
    fi
done
if (( VERBOSE >= 1 )) ; then
    _info "$LINENO" "done"
fi
summary
