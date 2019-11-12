#!/bin/sh

# Find yu.sh (tuned for Docker) and load modules
ROOT_DIR=$( cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P )
YUSH_DIR="$ROOT_DIR/.."
. "$YUSH_DIR/log.sh"

BLKSIZE=512

# Print usage on stderr and exit
usage() {
    [ -n "$1" ] && echo "$1" >/dev/stderr
    exitcode="${2:-1}"
    cat <<USAGE >&2

Description:

  $YUSH_APPNAME will wait for input to appear on stdin and start a program once
  input has started to appear with the initial and all upcoming input.

Usage:
  $(basename "$0") [-option arg --long-option(=)arg] [--] pipeline

  where all dash-led options are as follows (long options can be followed by
  an equal sign):
    -v | --verbose   Verbosity level
    -s | --size      Size of initial block
    --no-col(u)r     Force no colouring of logs

Data Integrity:

  By design, this program will leak an encoded (not encrypted) cache of the
  initial bytes in a temporary file.
USAGE
    exit "$exitcode"
}

while [ $# -gt 0 ]; do
    case "$1" in
    -v | --verbose)
        YUSH_LOG_LEVEL="$2"; shift 2;;
    --verbose=*)
        YUSH_LOG_LEVEL="${1#*=}"; shift 1;;

    -s | --size)
        BLKSIZE="$2"; shift 2;;
    --size=*)
        BLKSIZE="${1#*=}"; shift 1;;

    --non-interactive | --no-colour | --no-color)
        YUSH_LOG_COLOUR=0; shift 1;;

    --)
        shift; break;;

    -*)
        usage "$1 not a known option!"; exit;;

    *)
        break
        ;;
    esac
done

# Create a directory for temporary stuff
tmpdir=$(mktemp -d)

# Create a fifo to use for bytes transfer from our standard input to the
# destination program.
fifoname="$tmpdir"/fifo.$$
mkfifo -m 0600 "$fifoname"
yush_debug "Using fifo $fifoname"

# Read the first bytes
bytes=$(dd bs="$BLKSIZE" count=1 2>/dev/null | base64)
if [ -n "$bytes" ]; then
    # Now that we have some bytes, start the destination program in the
    # background, making sure that it will receive data from the fifo
    yush_info "First $BLKSIZE bytes read, starting $@ in the background"
    eval "$@" < "$fifoname" &

    # Cache the first bytes to a temporary file
    tmpfile="$tmpdir"/block.$$
    yush_debug "Caching first bytes at $tmpfile"
    if [ "$(uname -s)" = "Darwin" ]; then
        printf %s "$bytes" | base64 -D > "$tmpfile"
    else
        printf %s "$bytes" | base64 -d > "$tmpfile"
    fi

    # Now cat the content of the first bytes followed by everything else that
    # follows on the stdin to the fifo. At this point, the program that we have
    # started in the background is going to start receiving the data.
    cat "$tmpfile" - > "$fifoname"
fi

# Cleanup and wait for processes to finish
yush_debug "Cleaning away all resources under $tmpdir"
rm -rf "$tmpdir"
wait