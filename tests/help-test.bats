#!/usr/bin/env bats

workspace="/tmp/pb-updater-tests/"
pbUpdate="src/pb-update.sh"
botDir=""

load common/setup
load common/help

function setup() {
    local botsDir="${workspace%/}/test-bots"
    local botName="pp-bot"

    botDir=$(generateMockBot "$botsDir" "$botName") || comandFailure "generateMockBot" "Unable to create test bot"
}

function comandFailure() {
    local functionName="$1"
    local logMessage="$2"

    echo "Failed to execute command: '${functionName}', failed with '${logMessage}'"
    exit 1
}


@test "It displays help information" {
    run $pbUpdate -h

    printf -v stringified "%s\n" "${output[@]}"
    echo "$stringified" > z.stringified.txt
    echo "$(help.generateHelpOutput "$pbUpdate")" > z.expcted.txt

    [[ "$status" -eq 0 ]]
    [[ "${stringified%?}" == "$(help.generateHelpOutput "$pbUpdate")" ]]
}

@test "It backsup the bot" {
    skip
}
