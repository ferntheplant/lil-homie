#!/bin/bash
# Wrapper to run imessage-monitor with mise Python
# Save as: ~/lil-homie/run-imessage-monitor.sh

# Don't exit on error so we can debug
set +e

# Redirect to a debug log for troubleshooting
exec 2>> /tmp/imessage-monitor-wrapper-debug.log
echo "=== Wrapper started at $(date) ===" >&2

# Set up mise environment
export PATH="/Users/fjorn/.local/bin:$PATH"
export MISE_DATA_DIR="/Users/fjorn/.local/share/mise"

echo "PATH: $PATH" >&2
echo "MISE_DATA_DIR: $MISE_DATA_DIR" >&2

# Activate mise
eval "$(mise activate bash)" 2>&1 | tee -a /tmp/imessage-monitor-wrapper-debug.log
eval "$(mise hook-env)" 2>&1 | tee -a /tmp/imessage-monitor-wrapper-debug.log

# Check which python we're using
PYTHON_PATH=$(which python3)
echo "Using Python: $PYTHON_PATH" >&2
echo "Python version: $($PYTHON_PATH --version)" >&2

# Change to the script directory
cd /Users/fjorn/lil-homie
echo "Working directory: $(pwd)" >&2

# Run the Python script
echo "Executing: $PYTHON_PATH /Users/fjorn/lil-homie/imessage-monitor.py" >&2
exec "$PYTHON_PATH" /Users/fjorn/lil-homie/imessage-monitor.py
