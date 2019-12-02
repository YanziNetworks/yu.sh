#!/bin/sh

# Find yu.sh (tuned for Docker) and load modules
ROOT_DIR=$( cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P )
YUSH_DIR="$ROOT_DIR/.."
# shellcheck source=yu.sh/log.sh disable=SC1091
. "$YUSH_DIR/json.sh"

yush_json