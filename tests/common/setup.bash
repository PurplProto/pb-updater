#!/bin/bash

generateMockBot() {
    local parentDir="$1"
    local botName="$2"
    local botPath="${parentDir%/}/${botName}"

    mkdir -p "$botPath"

    echo "$botPath"
}
