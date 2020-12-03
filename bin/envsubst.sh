#!/bin/sh

set -eu

### AMLG_START ../log.sh ../multi-arch.sh
# Find yu.sh (tuned for Docker) and load modules
ROOT_DIR=$( cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P )
YUSH_DIR="$ROOT_DIR/.."
# shellcheck source=yu.sh/log.sh disable=SC1091
. "$YUSH_DIR/log.sh"
# shellcheck source=yu.sh/multi-arch.sh disable=SC1091
. "$YUSH_DIR/multi-arch.sh"
### AMLG_END

# Output destination, empty for stdout.
ENVSUBST_OUTPUT=${ENVSUBST_OUTPUT:-/dev/stdout}

# Print usage on stderr and exit
usage() {
    [ -n "$1" ] && echo "$1" >&2
    exitcode="${2:-1}"
    cat <<USAGE >&2

Description:

  $YUSH_APPNAME will substitute the value of environment variables.

Usage:
  $(basename "$0") [-option arg --long-option(=)arg] [--] [path]...

  where all dash-led options are as follows (long options can be followed by
  an equal sign):
    -v | --verbose   Verbosity level

Details:
  This is a pure shell implementation of envsubst in a eval-safe manner. It
  will substitute the content of environment variables in all files passed as
  a parameter to the destination path (or the stdout if no path was given).
  When no filepath are passed, input will be taken from stdin.

  Note that it does not support default values such as ${MYVAR:-default}
  constructs.

USAGE
    exit "$exitcode"
}

while [ $# -gt 0 ]; do
    case "$1" in
        -v | --verbose)
            # shellcheck disable=SC2034
            YUSH_LOG_LEVEL=$2; shift 2;;
        --verbose=*)
            # shellcheck disable=SC2034
            YUSH_LOG_LEVEL="${1#*=}"; shift 1;;

        -o | --output)
            # shellcheck disable=SC2034
            ENVSUBST_OUTPUT=$2; shift 2;;
        --output=*)
            # shellcheck disable=SC2034
            ENVSUBST_OUTPUT="${1#*=}"; shift 1;;

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

if [ "$#" -gt "0" ]; then
  for SRC in "$@"; do
    yush_envsubst < "$SRC" > "$ENVSUBST_OUTPUT"
  done
else
  yush_envsubst > "$ENVSUBST_OUTPUT"
fi
