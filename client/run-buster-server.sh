#!/bin/bash
[[ -e .buster-port ]] && BUSTER_PORT=$(cat .buster-port) || BUSTER_PORT=1111
BUSTER_SERVER="http://localhost:${BUSTER_PORT}"
BIN=./node_modules/.bin
if pgrep -lf "node.*buster-server.*$BUSTER_PORT" > /dev/null; then 
    echo ">> buster-server is already running"
    exit 1
else
    $BIN/buster-server -p $BUSTER_PORT &
    BUSTER_PID=$!
    trap "kill $BUSTER_PID" EXIT
    sleep .7
fi

if pgrep -lf "phantomjs.*buster.*$BUSTER_PORT" > /dev/null; then 
    echo ">> A phantomjs slave is already running"
else
    echo ">> Starting new phantomjs buster slave"
    phantomjs ./node_modules/buster/script/phantom.js "$BUSTER_SERVER/capture" \
        2>&1 | grep -v '.*Window not defined.*skipping' &
    PHANTOM_PID=$!
    trap "kill $PHANTOM_PID" EXIT
fi

wait
