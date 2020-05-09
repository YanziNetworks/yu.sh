#!/bin/sh

set -eu

# Find yu.sh (tuned for Docker) and load modules
ROOT_DIR=$( cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P )
YUSH_DIR="$ROOT_DIR/.."
# shellcheck source=yu.sh/log.sh disable=SC1091
. "$YUSH_DIR/log.sh"
# shellcheck source=yu.sh/log.sh disable=SC1091
. "$YUSH_DIR/file.sh"
# shellcheck source=yu.sh/log.sh disable=SC1091
. "$YUSH_DIR/text.sh"

AMLG_ROOT=${AMLG_ROOT:-}
AMLG_MINIFY=${AMLG_MINIFY:-0}

# Print usage on stderr and exit
usage() {
    [ -n "$1" ] && echo "$1" >&2
    exitcode="${2:-1}"
    cat <<USAGE >&2

Description:

  $YUSH_APPNAME will perform script amalgamation based on keywords.

Usage:
  $(basename "$0") [-option arg --long-option(=)arg] [--] flow_step ...

  where all dash-led options are as follows (long options can be followed by
  an equal sign):
    -v | --verbose   Verbosity level

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

        -r | --root)
            # shellcheck disable=SC2034
            AMLG_ROOT=$2; shift 2;;
        --root=*)
            # shellcheck disable=SC2034
            AMLG_ROOT="${1#*=}"; shift 1;;

        --minify)
            AMLG_MINIFY=1; shift;;

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

strip() {
    sed -E \
        -e 's/;[[:space:]]*#[[:space:][:alnum:]\-_.,;#]+$//' \
        -e 's/^[[:space:]]*#[^!].*$//' \
        -e 's/^[[:space:]]*#[[:space:]]*$//' \
        -e 's/^[[:space:]]*$//'
}

minify_line() {
    if [ "$AMLG_MINIFY" = "0" ]; then
        printf %s\\n "$1"
    else
        line=$(printf %s\\n "$1" | strip)
        yush_debug "Stripped: $1 => $line"
        if [ -n "$line" ]; then
            printf %s\\n "$line"
        fi
    fi
}

minify() {
    while IFS= read -r line || [ -n "$line" ]; do
        minify_line "$line"
    done < "$1"
}

inline() {
    for _p in $1; do
        if [ -f "$_p" ]; then
            if [ "$AMLG_MINIFY" = "0" ]; then
                echo ""
                echo "### Inlining $_p"
                cat "$_p"
                echo ""
                echo "### End of inlining $_p"
            else
                minify "$_p"
                echo ""
            fi
        fi
    done
}

amalgamation() {
    # Decide which root directory to use for relative files.
    if [ "$AMLG_ROOT" = "" ]; then
        if [ "$1" = "/dev/stdin" ]; then
            _dir=
        else
            _dir=$(yush_dirname "$(yush_abspath "$1")")
        fi
    else
        _dir=$AMLG_ROOT
    fi

    # Do amalgamation, will remove everything between ### AMLG_START and ###
    # AMLG_END markers. All filenames after the ### AMLG_START marker will be
    # inlined, relative to the directory from above when relevant.
    _skip=0
    while IFS= read -r line || [ -n "$line" ]; do
        if [ "$_skip" = "0" ]; then
            if printf %s\\n "$line" | grep -Eiq '^###[[:space:]]+AMLG_START'; then
                _skip=1
                for fpath in $(printf %s\\n "$line" | sed -E 's/^###[[:space:]]+AMLG_START//i'); do
                    if [ "$_dir" != "" ] && ! yush_is_abspath "$fpath"; then
                        fpath=$(printf %s\\n "$fpath" | sed 's/^\.\///')
                        _rpath=$(yush_abspath "${_dir}/$fpath")
                        inline "$_rpath"
                    else
                        inline "$fpath"
                    fi
                done
            else
                minify_line "$line"
            fi
        elif printf %s\\n "$line" | grep -Eiq '^###[[:space:]]+AMLG_END'; then
            _skip=0
        fi
    done < "$1"
}


if [ "$#" -gt "0" ]; then
    for SRC in "$@"; do
        amalgamation "$SRC"
    done
else
    amalgamation /dev/stdin
fi
