#!/usr/bin/env bash
set -e

source ../.venv/bin/activate

PYTEST_FLAGS="-s --log-cli-level=INFO -o log_cli=True"


# User did not pass any arguments
if [ "$#" -eq 0 ]; then
  echo "Error: no cocotb test file provided."
  echo "Usage: $0 test_eth.py [additional pytest args...]"
  exit 1
fi

SIM=verilator WAVES=1 GUI=0 HDL_TOPLEVEL_LANG=verilog \
  pytest $PYTEST_FLAGS "$@"