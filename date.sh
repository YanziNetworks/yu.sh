#!/bin/sh

# Return the approx. number of seconds for the human-readable period passed as a
# parameter
yush_howlong() {
    if echo "$1"|grep -Eqo '[0-9]+[[:space:]]*[yY]'; then
        len=$(echo "$1"  | sed -En 's/([0-9]+)[[:space:]]*[yY].*/\1/p')
        expr "$len" \* 31536000
        return
    fi
    if echo "$1"|grep -Eqo '[0-9]+[[:space:]]*[Mm][Oo]'; then
        len=$(echo "$1"  | sed -En 's/([0-9]+)[[:space:]]*[Mm][Oo].*/\1/p')
        expr "$len" \* 2592000
        return
    fi
    if echo "$1"|grep -Eqo '[0-9]+[[:space:]]*m'; then
        len=$(echo "$1"  | sed -En 's/([0-9]+)[[:space:]]*m.*/\1/p')
        expr "$len" \* 2592000
        return
    fi
    if echo "$1"|grep -Eqo '[0-9]+[[:space:]]*[Ww]'; then
        len=$(echo "$1"  | sed -En 's/([0-9]+)[[:space:]]*[Ww].*/\1/p')
        expr "$len" \* 604800
        return
    fi
    if echo "$1"|grep -Eqo '[0-9]+[[:space:]]*[Dd]'; then
        len=$(echo "$1"  | sed -En 's/([0-9]+)[[:space:]]*[Dd].*/\1/p')
        expr "$len" \* 86400
        return
    fi
    if echo "$1"|grep -Eqo '[0-9]+[[:space:]]*[Hh]'; then
        len=$(echo "$1"  | sed -En 's/([0-9]+)[[:space:]]*[Hh].*/\1/p')
        expr "$len" \* 3600
        return
    fi
    if echo "$1"|grep -Eqo '[0-9]+[[:space:]]*[Mm][Ii]'; then
        len=$(echo "$1"  | sed -En 's/([0-9]+)[[:space:]]*[Mm][Ii].*/\1/p')
        expr "$len" \* 60
        return
    fi
    if echo "$1"|grep -Eqo '[0-9]+[[:space:]]*M'; then
        len=$(echo "$1"  | sed -En 's/([0-9]+)[[:space:]]*M.*/\1/p')
        expr "$len" \* 60
        return
    fi
    if echo "$1"|grep -Eqo '[0-9]+[[:space:]]*[Ss]'; then
        len=$(echo "$1"  | sed -En 's/([0-9]+)[[:space:]]*[Ss].*/\1/p')
        echo "$len"
        return
    fi
    if echo "$1"|grep -E '[0-9]+'; then
        echo "$1"
        return
    fi
}

# Convert a number of seconds to a human-friendly string mentioning days, hours,
# etc.
yush_human_period(){
    t=$1

    d=$((t/60/60/24))
    h=$((t/60/60%24))
    m=$((t/60%60))
    s=$((t%60))

    if [ $d -gt 0 ]; then
            [ $d = 1 ] && printf "%d day " $d || printf "%d days " $d
    fi
    if [ $h -gt 0 ]; then
            [ $h = 1 ] && printf "%d hour " $h || printf "%d hours " $h
    fi
    if [ $m -gt 0 ]; then
            [ $m = 1 ] && printf "%d minute " $m || printf "%d minutes " $m
    fi
    if [ $d = 0 ] && [ $h = 0 ] && [ $m = 0 ]; then
            [ $s = 1 ] && printf "%d second" $s || printf "%d seconds" $s
    fi
    printf '\n'
}


# Returns the number of seconds since the epoch for the ISO8601 date passed as
# an argument. This will only recognise a subset of the standard, i.e. dates
# with milliseconds, microseconds, nanoseconds or none specified, and timezone
# only specified as diffs from UTC, e.g. 2019-09-09T08:40:39.505-07:00 or
# 2019-09-09T08:40:39.505214+00:00. The special Z timezone (i.e. UTC) is also
# recognised. The implementation actually computes the ms/us/ns whenever they
# are available, but discards them.
yush_iso8601() {
    # Arrange for ns to be the number of nanoseconds.
    ds=$(echo "$1"|sed -E 's/([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})(\.([0-9]{3,9}))?([+-]([0-9]{2}):([0-9]{2})|Z)?/\8/')
    ns=0
    if [ -n "$ds" ]; then
        if [ "${#ds}" = "10" ]; then
            ds=$(echo "$ds" | sed 's/^0*//')
            ns=$ds
        elif [ "${#ds}" = "7" ]; then
            ds=$(echo "$ds" | sed 's/^0*//')
            ns=$((1000*ds))
        else
            ds=$(echo "$ds" | sed 's/^0*//')
            ns=$((1000000*ds))
        fi
    fi


    # Arrange for tzdiff to be the number of seconds for the timezone.
    tz=$(echo "$1"|sed -E 's/([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})(\.([0-9]{3,9}))?([+-]([0-9]{2}):([0-9]{2})|Z)?/\9/')
    tzdiff=0
    if [ -n "$tz" ]; then
        if [ "$tz" = "Z" ]; then
            tzdiff=0
        else
            hrs=$(printf "%d" "$(echo "$tz" | sed -E 's/[+-]([0-9]{2}):([0-9]{2})/\1/')")
            mns=$(printf "%d" "$(echo "$tz" | sed -E 's/[+-]([0-9]{2}):([0-9]{2})/\2/')")
            sign=$(echo "$tz" | sed -E 's/([+-])([0-9]{2}):([0-9]{2})/\1/')
            secs=$((hrs*3600+mns*60))
            if [ "$sign" = "-" ]; then
                tzdiff=$((-secs))
            else
                tzdiff=$secs
            fi
        fi
    fi

    # Extract UTC date and time into something that date can understand, then
    # add the number of seconds representing the timezone.
    utc=$(echo "$1"|sed -E 's/([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})(\.([0-9]{3,9}))?([+-]([0-9]{2}):([0-9]{2})|Z)?/\1-\2-\3 \4:\5:\6/')
    if [ "$(uname -s)" = "Darwin" ]; then
        secs=$(date -u -j -f "%Y-%m-%d %H:%M:%S" "$utc" +"%s")
    else
        secs=$(date -u -d "$utc" +"%s")
    fi
    expr "$secs" + \( "$tzdiff" \)
}
