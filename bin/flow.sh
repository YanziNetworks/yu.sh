#!/bin/sh

# Find yu.sh (tuned for Docker) and load modules
ROOT_DIR=$( cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P )
YUSH_DIR="$ROOT_DIR/.."
# shellcheck source=yu.sh/log.sh disable=SC1091
. "$YUSH_DIR/log.sh"
# shellcheck source=yu.sh/log.sh disable=SC1091
. "$YUSH_DIR/file.sh"

FLOW_COMMAND=${FLOW_COMMAND:-}
FLOW_SUBST=${FLOW_SUBST:-1}
FLOW_PULSE=${FLOW_PULSE:-1}
FLOW_END=${FLOW_END:-}


# Print usage on stderr and exit
usage() {
    [ -n "$1" ] && echo "$1" >/dev/stderr
    exitcode="${2:-1}"
    cat <<USAGE >&2

Description:

  $YUSH_APPNAME automates line-based interactive sessions such as telnet
  dialogs or websocket connections.

Usage:
  $(basename "$0") [-option arg --long-option(=)arg] [--] flow_step ...

  where all dash-led options are as follows (long options can be followed by
  an equal sign):
    -v | --verbose   Verbosity level
    --no-subst       Do not substitute environment variables in flow specs.
    -c | --command   Command to execute and "interact" with (see below)
    -e | --end       Command to execute once interaction has ended, before
                     exit.

  Flow specifications describe the various steps of the interaction against
  the command that is placed under $YUSH_APPNAME control via fifos. In
  specifications, the environment variable references will be substituted,
  i.e. if XXX is an environment variable, any occurence of $XXX will be
  replaced by the value of XXX. In specifications, empty lines and lines
  starting with a # (hash-mark) will be ignored. A flow step specification
  needs to end with an empty line (or a comment). Step specifications should
  contain lines where the key is separated from its value using the equal
  sign. The recognised keys are as follows:

  wait      A regular expression to wait for the end of a possible header.
            Lines will be eaten and ignored until the expression matches.
  input     Line to send to the input of the program, once the header has
            finished (if relevant)
  sleep     Sleep this many seconds before sending input line (default: 0)
  continue  When a line matches this regular expression, jump to next flow
  output    When a line matches this regular expression, output it on the
            standard output
  abort     When a line matches this regular expression, abort the entire
            flow control and proceed to exit.
  timeout   Number of seconds to timeout before aborting flow. Default is
            to never timeout.

  If the first character after the equal sign is an @ (arobas), then all
  remaining characters forms the path to a file where to find the content
  of the key. Relative files will automatically be understood relative to
  the directory containing the step specification. The content of these
  file will be substituted with environment variables and all line endings
  will be removed.

USAGE
    exit "$exitcode"
}

while [ $# -gt 0 ]; do
    case "$1" in
        -c | --command)
            FLOW_COMMAND="$2"; shift 2;;
        --command=*)
            FLOW_COMMAND="${1#*=}"; shift 1;;

        -e | --end)
            FLOW_END="$2"; shift 2;;
        --end=*)
            FLOW_END="${1#*=}"; shift 1;;

        --no-subst)
            FLOW_SUBST=0;;

        --no-pulse)
            FLOW_PULSE=0;;

         -v | --verbose)
            # shellcheck disable=SC2034
            YUSH_LOG_LEVEL=$2; shift 2;;
        --verbose=*)
            # shellcheck disable=SC2034
            YUSH_LOG_LEVEL="${1#*=}"; shift 1;;

        --non-interactive | --no-colour | --no-color)
            # shellcheck disable=SC2034
            YUSH_LOG_COLOUR=0; shift 1;;

        -h | --help)
            usage "" 0;;

        --)
            shift; break;;
        -*)
            usage "Unknown option: $1 !";;
        *)
            break;;

    esac
done

# Create a directory for temporary stuff
tmpdir=$(mktemp -d)

# Create a fifo to use for bytes transfer from our standard input to the
# destination program.
yush_debug "Creating fifos in $tmpdir"
to="$tmpdir"/to.$$
from="$tmpdir"/from.$$
mkfifo -m 0600 "$to"
mkfifo -m 0600 "$from"

if yush_loglevel_le debug; then
    yush_notice "Starting command $FLOW_COMMAND"
    $FLOW_COMMAND < "$to" > "$from" &
else
    yush_notice "Starting command $FLOW_COMMAND, ignoring its stderr"
    $FLOW_COMMAND < "$to" > "$from" 2> /dev/null &
fi
PID=$!
sleep 1000000 > "$to" &
ALIVE_PID=$!
yush_debug "Command $FLOW_COMMAND has pid: $PID"

vars_subst() {
    substituted=$1
    yush_trace "Performing substitution in $1"
    environment=$(env|grep -E '^[[:upper:]_]+=')
    while IFS='=' read -r var val; do
        substituted=$(echo "$substituted" | sed -e "s!\$${var}!$val!g")
    done <<EOF
$environment
EOF
    echo "$substituted"
}

one_line(){ tr -d '\r\n'; }
remove_space(){ tr -d '[:space:]'; }

doexit() {
    exitcode="${1:-0}"
    if ps -o pid | tail -n 1 | grep -q "$PID"; then
        yush_notice "Killing sub-command at $PID"
        kill -15 "$PID"
    fi
    if ps -o pid | tail -n 1 | grep -q "$ALIVE_PID"; then
        yush_notice "Killing keep-alive command at $ALIVE_PID"
        kill -15 "$ALIVE_PID"
    fi
    yush_debug "Removing fifos under $tmpdir"
    rm -rf "$tmpdir"
    [ -z "$FLOW_END" ] && exit "$exitcode"
    yush_notice "Executing $FLOW_END in place"
    exec "$FLOW_END";   # Only reached when non-empty
}

if [ "$FLOW_PULSE" ]; then
    yush_debug "Starting pulse in background"
    if yush_loglevel_le debug; then
        while true; do echo ""; sleep 1; done > "$from" 2>/dev/null &
    else
        while true; do echo ""; sleep 1; done > "$from" 2>/dev/null &
    fi
fi

while [ $# -gt 0 ]; do
    # Read content of contract
    wait=""
    input=""
    output=""
    continue=""
    abort=""
    timeout=-1
    sleep=0
    yush_info "Reading flow: $1"
    while IFS='=' read -r key val; do
        # Skip over lines containing comments.
        # (Lines starting with '#').
        [ "${key##\#*}" ] || continue

        if [ -n "$key" ]; then
            if [ "$FLOW_SUBST" = "1" ]; then
                val=$(vars_subst "$val")
            fi

            if [ "${val:0:1}" = "@" ]; then
                fpath=${val:1}
                if [ "${fpath:0:1}" != "/" ]; then
                    fpath="$(yush_dirname "$1")"/"${fpath}"
                fi
                yush_info "In $(yush_basename "$1"), read value of $key from $fpath"
                val=$(one_line < "$fpath")
                if [ "$FLOW_SUBST" = "1" ]; then
                    val=$(vars_subst "$val")
                fi
            fi
            yush_debug "In $(yush_basename "$1"): Setting $key=$val"
            export "${key}=${val}" 2>/dev/null || yush_warn "warning $key is not a valid variable name"
        fi
    done < "$1"

    if [ -n "$input" ]; then
        if [ -n "$wait" ]; then
            STATE=WAITING
        else
            yush_debug "No header to wait, pushing $input"
            STATE=OUTPUT
            if [ "$sleep" -gt "0" ]; then
                yush_debug "Sleeping $sleep before pushing input"
                sleep "$sleep"
            fi
            HEADER_SECS=$(date -u +'%s')
            printf "%s\n" "$input" > "$to"
        fi
        while IFS= read -r line; do
            case $STATE in
                WAITING)
                    yush_trace "Read: $line"
                    if echo "$line" | grep -Eqo "$wait"; then
                        yush_debug "End of header detected, matching $wait pushing $input"
                        STATE=OUTPUT
                        if [ "$sleep" -gt "0" ]; then
                            yush_debug "Sleeping $sleep before pushing input"
                            sleep "$sleep"
                        fi
                        HEADER_SECS=$(date -u +'%s')
                        printf "%s\n" "$input" > "$to"
                    fi
                    ;;
                OUTPUT)
                    if [ -n "$line" ]; then
                        yush_debug "Read: $line"
                    else
                        yush_trace "Read: $line"
                    fi

                    now=$(date -u +'%s')
                    elapsed=$((now-HEADER_SECS))

                    if [ -n "$line" ] && [ -n "$output" ] && echo "$line" | grep -Eqo "$output"; then
                        yush_debug "Output matched $output, output"
                        echo "$line"
                        break
                    fi
                    if [ -n "$line" ] && [ -n "$continue" ] && echo "$line" | grep -Eqo "$continue"; then
                        yush_debug "Output matched $continue, continuing to next flow"
                        break
                    fi
                    if [ -n "$line" ] && [ -n "$abort" ] && echo "$line" | grep -Eqo "$abort"; then
                        yush_debug "Output matched $abort, aborting all flows"
                        doexit 1
                        break
                    fi
                    if [ -n "$timeout" ] && [ "$timeout" -gt "0" ] && [ "$elapsed" -ge "$timeout" ]; then
                        yush_debug "At least $timeout seconds since header, aborting"
                        doexit 1
                        break
                    fi
                    ;;
            esac
        done < "$from"
    else
        yush_warn "No input to wait for in flow $1"
    fi

    shift
done

doexit