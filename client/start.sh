#!/bin/bash

if which foreman &>/dev/null; then 
    foreman start
else
    echo "You need to install 'foreman' (a ruby gem) and 'node/npm'" >&2
    exit 1
fi
