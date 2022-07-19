#!/usr/bin/env bash
#
# Extract day data from a csv file and plot it.
#
# Usage:
#   ./plot-day.sh 2022-07-19 moniconn-2022-07-18-month.csv
#
# FUNCTIONS
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

# MAIN
PATTERN="$1"
CSV="$2"

if [ -z "$PATTERN" ] ; then
    _err "$LINENO" "Pattern not specified as first argument"
    exit 1
fi

if [ -z "$CSV" ] ; then
    _err "$LINENO" "Input CSV file not specified as the as second argument"
    exit 1
fi

GP=$(ls -1 *.gp)
OUT="/tmp/plot-day-$PATTERN.csv"
head -1 "$CSV" > "$OUT"
grep "$PATTERN" "$CSV" >> "$OUT"
./"$GP" "$OUT"
