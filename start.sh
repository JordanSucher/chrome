#!/bin/bash
set -e

# When docker restarts, this file is still there,
# so we need to kill it just in case
[ -f /tmp/.X99-lock ] && rm -f /tmp/.X99-lock

_kill_procs() {
  kill -TERM $node
  kill -TERM $xvfb
  kill -TERM $chrome  # Add this line to ensure Chrome also gets killed on termination signals
}

# Relay quit commands to processes
trap _kill_procs SIGTERM SIGINT

Xvfb :99 -screen 0 1024x768x16 -nolisten tcp -nolisten unix &
xvfb=$!

export DISPLAY=:99

# Start Chrome with remote debugging enabled and other necessary flags
google-chrome-stable --headless --remote-debugging-port=9222 --no-sandbox --disable-dev-shm-usage &
chrome=$!  # Store the PID of the Chrome process for later

dumb-init -- node ./build/index.js $@ &
node=$!

wait $node
wait $xvfb
wait $chrome  # Wait for Chrome to exit before exiting the script
