#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"

VIVADO_SETTINGS="/home/evanwu03/vivado/2025.2/Vivado/settings64.sh"

BUILD_MODE="${BUILD_MODE:-non_project}"   # non_project or project

mkdir -p "$BUILD_DIR"

if ! command -v vivado >/dev/null 2>&1; then
    if [[ -f "$VIVADO_SETTINGS" ]]; then
        source "$VIVADO_SETTINGS"
    else
        echo "ERROR: vivado not found in PATH."
        echo "Also could not find settings64.sh at:"
        echo "  $VIVADO_SETTINGS"
        exit 1
    fi
fi

if ! command -v vivado >/dev/null 2>&1; then
    echo "ERROR: sourced settings64.sh, but vivado is still not in PATH."
    exit 1
fi


case "$BUILD_MODE" in
    non_project)
        TCL_SCRIPT="$SCRIPT_DIR/build.tcl"
        LOG_NAME="vivado_non_project"
        ;;

    project)
        TCL_SCRIPT="$SCRIPT_DIR/project_mode.tcl"
        LOG_NAME="vivado_project"
        ;;

    *)
        echo "ERROR: unknown BUILD_MODE '$BUILD_MODE'"
        echo "Valid modes: non_project, project"
        exit 1
        ;;
esac


vivado -mode batch \
    -source "$TCL_SCRIPT" \
    -journal "$BUILD_DIR/${LOG_NAME}.jou" \
    -log "$BUILD_DIR/${LOG_NAME}.log"