#!/bin/sh

# Find yu.sh (tuned for Docker) and load modules
ROOT_DIR=$( cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P )
YUSH_DIR="$ROOT_DIR/.."
# shellcheck source=yu.sh/log.sh disable=SC1091
. "$YUSH_DIR/log.sh"
# shellcheck source=yu.sh/log.sh disable=SC1091
. "$YUSH_DIR/file.sh"
# shellcheck source=yu.sh/log.sh disable=SC1091
. "$YUSH_DIR/text.sh"

FLOW_COMMAND=${FLOW_COMMAND:-}
FLOW_SUBST=${FLOW_SUBST:-1}
FLOW_PULSE=${FLOW_PULSE:-1}
FLOW_END=${FLOW_END:-}
FLOW_PREFIX=${FLOW_PREFIX:-"FLOWSTEP_"}


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
    -p | --prefix    Prefix to add to env. variables created with output of
                     steps (default: FLOWSTEP_)

  Flow specifications describe the various steps of the interaction against
  the command that is placed under $YUSH_APPNAME control via fifos. In
  specifications, the environment variable references will be substituted,
  i.e. if XXX is an environment variable, any occurence of $XXX will be
  replaced by the value of XXX. After every successfull step, an environment
  value containing the output of the step will be created. The name of this
  variable will start with the prefix and continue with the basename of the
  step specification, in uppercase and where all non alpha numeric characters
  are replaced with underscores.
  
  In specifications, empty lines and lines starting with a # (hash-mark)
  will be ignored. A flow step specification needs to end with an empty line
  (or a comment). Step specifications should contain lines where the key is
  separated from its value using the equal sign. The recognised keys are as
  follows:

  wait      A regular expression to wait for the end of a possible header.
            Lines will be eaten and ignored until the expression matches.
  input     Line to send to the input of the program, once the header has
            finished (if relevant)
  sleep     Sleep this many seconds before sending input line (default: 0)
  continue  When a line matches this regular expression, jump to next flow
            creating an environment variable with this output (or
            transformed, see below)
  output    When a line matches this regular expression, output it on the
            standard output (or transformed, see below)
  abort     When a line matches this regular expression, abort the entire
            flow control and proceed to exit.
  timeout   Number of seconds to timeout before aborting flow. Default is
            to never timeout.
  transform Command to execute on the output (continue or output key)
            before continuing to next step or outputing result. This will
            usually be a "clever" sed substitution command.

  If the first character after the equal sign is an @ (arobas), then all
  remaining characters forms the path to a file where to find the content
  of the key. Relative files will automatically be understood relative to
  the directory containing the step specification. The content of these
  file will be substituted with environment variables and all line endings
  will be removed.

  Note, if the command ends before the end of the flows, it will be
  restarted as appropriate. Restart only occur at the start of each flow.

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

        -p | --prefix)
            FLOW_PREFIX="$2"; shift 2;;
        --prefix=*)
            FLOW_PREFIX="${1#*=}"; shift 1;;

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

PID=
ALIVE_PID=
RUNNING_SLAVE=

start_slave() {
    # Create fifos to use for bytes transfer to/from our standard output/input
    # to the destination program.
    yush_debug "Creating fifos in $tmpdir"
    pfx=$(yush_password 5)
    to="$tmpdir"/to.$$.$pfx
    from="$tmpdir"/from.$$.$pfx
    mkfifo -m 0600 "$to"
    mkfifo -m 0600 "$from"

    # Start slave command in the background. When tracing, we arrange not to
    # throw away the standard error in order to be able to catch possible
    # problems.
    if yush_loglevel_le debug; then
        yush_notice "Starting command $1"
        $1 < "$to" > "$from" &
    else
        yush_notice "Starting command $1, ignoring its stderr"
        $1 < "$to" > "$from" 2> /dev/null &
    fi

    # Remember about slave PID and arrange to keep alive the fifo from start
    PID=$!
    RUNNING_SLAVE=$1
    sleep 1000000 > "$to" &
    ALIVE_PID=$!
    yush_debug "Command $1 has pid: $PID"

    # Pulse an empty line every second into the output so we can easily
    # implements timeouts in the main loop.
    if [ "$FLOW_PULSE" ]; then
        yush_debug "Starting pulse in background"
        if yush_loglevel_le debug; then
            while true; do echo ""; sleep 1; done > "$from" 2>/dev/null &
        else
            while true; do echo ""; sleep 1; done > "$from" 2>/dev/null &
        fi
    fi
}

# This is a very-poor-man's envsubst. It has no support for default values.
vars_subst() {
    substituted=$1
    yush_trace "Performing substitution in $1"
    environment=$(env|grep -E '^[0-9[:upper:]_]+=')
    while IFS='=' read -r var val; do
        substituted=$(echo "$substituted" | sed -e "s!\$${var}!$val!g")
    done <<EOF
$environment
EOF
    echo "$substituted"
}

one_line(){ tr -d '\r\n'; }
remove_space(){ tr -d '[:space:]'; }
pid_running() { ps -o pid | tail -n +1 | grep -q "$1"; }
kill_if_exist() {
    if [ -n "$1" ] && pid_running "$1"; then
        yush_notice "Killing $2 command at $1"
        kill -15 "$1"
    fi
}

# Exit, arranging to clean everything up before quiting (fifos, sub-programs,
# etc.)
doexit() {
    exitcode="${1:-0}"

    # Kill sub-processes
    kill_if_exist "$PID" "slave"
    kill_if_exist "$ALIVE_PID" "keep-alive"

    # Cleanup fifos directory
    yush_debug "Removing fifos under $tmpdir"
    rm -rf "$tmpdir"

    # Exit (through external program?)
    [ -z "$FLOW_END" ] && exit "$exitcode"
    yush_notice "Executing $FLOW_END in place"
    exec "$FLOW_END";   # Only reached when non-empty
}

while [ $# -gt 0 ]; do
    # Read content of contract
    wait=""
    input=""
    output=""
    continue=""
    transform=""
    abort=""
    slave=$FLOW_COMMAND
    timeout=-1
    sleep=0
    yush_info "Reading flow: $1"
    varname=$(yush_basename "$1")
    varname=${FLOW_PREFIX}$(echo "${varname%%.*}" | one_line | tr '[:lower:]' '[:upper:]' | tr -C '[:alnum:]' '_')
    while IFS='=' read -r key val; do
        # Skip over lines containing comments.
        # (Lines starting with '#').
        [ "${key##\#*}" ] || continue

        if [ -n "$key" ]; then
            if [ "$FLOW_SUBST" = "1" ]; then
                val=$(vars_subst "$val")
            fi

            if [ "$(echo "$val" | cut -c1-1)" = "@" ]; then
                fpath=$(echo "$val" | cut -c2-)
                first_char=$(echo "$fpath" | cut -c1-1)
                if [ "$first_char" != "/" ] && [ "$first_char" != "~" ]; then
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
        # Kill currently running slave if we have one and if we have just
        # changed the slave specification at this step.
        if [ -n "$RUNNING_SLAVE" ] && [ "$RUNNING_SLAVE" != "$slave" ]; then
            yush_notice "Slave has changed to $slave, forcefully killing previous"
            kill_if_exist "$PID" "slave"
            kill_if_exist "$ALIVE_PID" "keep-alive"
            PID=
            ALIVE_PID=
        fi

        # Start slave command if it is not running. This might have the side
        # effect of starting the command several time, which is on purpose (such
        # as when automating websocket connections with "one-shot"
        # question/answer underlying tools.)
        if [ -z "$PID" ] || ! pid_running "$PID"; then
            kill_if_exist "$ALIVE_PID" "keep-alive"
            start_slave "$slave"
        fi

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
                        if [ -n "$transform" ]; then
                            yush_debug "Transforming output through $transform"
                            value=$(echo "$line" | eval $transform)
                        else
                            value=$line
                        fi
                        echo "$value"
                        break
                    fi
                    if [ -n "$line" ] && [ -n "$continue" ] && echo "$line" | grep -Eqo "$continue"; then
                        yush_debug "Output matched $continue, continuing to next flow"
                        if [ -n "$transform" ]; then
                            yush_debug "Transforming output through $transform"
                            value=$(echo "$line" | eval $transform)
                        else
                            value=$line
                        fi
                        yush_debug "Storing in $varname content of (transformed) line: $value"
                        export "${varname}=${value}"
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

    # shellcheck disable=SC2163
    export "${varname}"
    shift
done
doexit