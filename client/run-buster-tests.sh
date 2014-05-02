#!/bin/bash

[[ -e .buster-port ]] && BUSTER_PORT=$(cat .buster-port) || BUSTER_PORT=1111
[[ -e ~/.buster_selector ]] && TEST_SELECTOR=$(cat ~/.buster_selector) || TEST_SELECTOR=""
[[ -e ~/.buster_reporter ]] && REPORTER=$(cat ~/.buster_reporter) || REPORTER="brief"
$DIR/run-buster-server.sh &
if [[ ! -z $MANAGE_SERVER ]]; then 
    SERVER_PID=$?
    trap "kill $SERVER_PID" EXIT
fi

./node_modules/.bin/buster-test -r "$REPORTER" -s "http://localhost:${BUSTER_PORT}" $TEST_SELECTOR $@
RCODE=$?

exit $RCODE
