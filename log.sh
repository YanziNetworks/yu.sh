#!/bin/sh

set -e


#### Following variables can be tweeked/changed from the outside, they all have
#### good defaults.

# YUSH_APPNAME is the name of the application that is inserted in the logs, all
# logging functions also take an extra argument that will blindly replace the
# name of application, e.g. for printing the name of an internal module or
# similar.
if [ -z "${YUSH_APPNAME:-}" ]; then
    YUSH_APPNAME="${0#\./}"
    YUSH_APPNAME="${YUSH_APPNAME##/*/}"
    YUSH_APPNAME="${YUSH_APPNAME%.*}"
fi

# YUSH_LOG_PATH is the location of the log. Lines will be appended to that file.
# It defaults to the standard error.
[ -z "${YUSH_LOG_PATH:-}" ] && YUSH_LOG_PATH=/dev/stderr

# YUSH_LOG_LEVEL is the logging level that decides which lines will be output or
# kept away from the log. Available levels are: TRACE, DEBUG, INFO, NOTICE,
# WARN, ERROR. The default is error.
[ -z "${YUSH_LOG_LEVEL:-}" ] && YUSH_LOG_LEVEL=INFO

# YUSH_LOG_COLOUR should be 1 or 0 and decides if log lines should use colouring
# or not.
if [ -z "${YUSH_LOG_COLOUR:-}" ]; then
    if [ -t 1 ]; then
        YUSH_LOG_COLOUR=1
    else
        YUSH_LOG_COLOUR=0
    fi
fi

# YUSH_LOG_DATE_FORMAT is the date format used for timestamps inserted in log lines.
[ -z "${YUSH_LOG_DATE_FORMAT:-}" ] && YUSH_LOG_DATE_FORMAT="%Y%m%d-%H%M%S"


# This is the API for the log module. Each function takes at least a message to
# log. When a second argument is present, it should be the name of the module
# that is creating the log line. The default log at yush_log() behaves like
# yush_info()
yush_trace()    { __yush_log "$1" "TRACE" "${2:-}"; }
yush_debug()    { __yush_log "$1" "DEBUG" "${2:-}"; }
yush_info()     { __yush_log "$1" "INFO" "${2:-}"; }
yush_notice()   { __yush_log "$1" "NOTICE" "${2:-}"; }
yush_warn()     { __yush_log "$1" "WARN" "${2:-}"; }
yush_error()    { __yush_log "$1" "ERROR" "${2:-}"; }
yush_log()      { __yush_log "$1" "INFO" "${2:-}"; }

# A number of utility functions to colourise the string passed as an argument
# whenever YUSH_LOG_COLOUR is set to 1.
yush_green() {
    if [ "$YUSH_LOG_COLOUR" = "1" ]; then
        printf '\033[1;31;32m%b\033[0m' "$1"
    else
        printf -- "%b" "$1"
    fi
}

yush_red() {
    if [ "$YUSH_LOG_COLOUR" = "1" ]; then
        printf '\033[1;31;40m%b\033[0m' "$1"
    else
        printf -- "%b" "$1"
    fi
}

yush_yellow() {
    if [ "$YUSH_LOG_COLOUR" = "1" ]; then
        printf '\033[1;31;33m%b\033[0m' "$1"
    else
        printf -- "%b" "$1"
    fi
}

yush_blue() {
    if [ "$YUSH_LOG_COLOUR" = "1" ]; then
        printf '\033[1;31;34m%b\033[0m' "$1"
    else
        printf -- "%b" "$1"
    fi
}

yush_cyan() {
    if [ "$YUSH_LOG_COLOUR" = "1" ]; then
        printf '\033[1;31;36m%b\033[0m' "$1"
    else
        printf -- "%b" "$1"
    fi
}

yush_magenta() {
    if [ "$YUSH_LOG_COLOUR" = "1" ]; then
        printf '\033[1;31;35m%b\033[0m' "$1"
    else
        printf -- "%b" "$1"
    fi
}

yush_dark_gray() {
    if [ "$YUSH_LOG_COLOUR" = "1" ]; then
        printf '\033[1;31;90m%b\033[0m' "$1"
    else
        printf -- "%b" "$1"
    fi
}

yush_light_gray() {
    if [ "$YUSH_LOG_COLOUR" = "1" ]; then
        printf '\033[1;31;37m%b\033[0m' "$1"
    else
        printf -- "%b" "$1"
    fi
}


# Everthing here below are private function for the internal implementation of
# the module.

# Return the numeric log level value for the argument. We only trigger on the
# first letters, independently of the casing and also recognise existing numeric
# values. Anything else defaults to info.
__yush_level() {
    case "$1" in
        T* | t* ) echo "0"; return;;
        D* | d* ) echo "1"; return;;
        I* | i* ) echo "2"; return;;
        N* | n* ) echo "3"; return;;
        W* | w* ) echo "4"; return;;
        E* | e* ) echo "5"; return;;
        [0-5]   ) echo "$1"; return;;
        *       ) echo "2"; return;;
    esac
}

# Return a textual representation of the number log level value passed as an
# argument, coloured if necessary.
__yush_coloured_level() {
    case "$1" in
        0) yush_dark_gray " trace"; return;;
        1) yush_light_gray " debug"; return;;
        2) yush_cyan " info "; return;;
        3) yush_yellow "notice"; return;;
        4) yush_red " WARN "; return;;
        5) yush_magenta " ERROR"; return;;
        *) echo "$1"; return;;
    esac
}

# Print a log line to the destination path. Arguments are, in order:
# - the text of the log.
# - the level of the log (defaults to INFO)
# - the app name or module producing the log (defaults to YUSH_APPNAME)
__yush_log() {
    out_level=$(__yush_level "$YUSH_LOG_LEVEL")
    in_level=$(__yush_level "${2:-INFO}")
    if [ "$in_level" -ge "$out_level" ]; then
        printf "[%s] [%s] [%s] %s\n" \
                    "$(__yush_coloured_level "$in_level")" \
                    "$(date +"$YUSH_LOG_DATE_FORMAT")" \
                    "$(yush_blue "${3:-$YUSH_APPNAME}")" \
                    "$1" >>$YUSH_LOG_PATH
    fi
}
