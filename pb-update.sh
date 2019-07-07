#!/bin/bash

################################################################################
#   Author:      PairedPrototype                                               #
#   FileName:    pb-update.sh                                                  #
#   Description: Back up PB's database, config and other non-standard          #
#                files (modified files)                                        #
#   Version:     1.0.0                                                         #
################################################################################

##                               User Variables                               ##

##     For ease of use when hosting a single bot, you should set these to     ##
## your own needs. Otherwise, these can all be set through the calling flags. ##

botPath=""                               # -b | Path to the bot's root directory
debugEnabled=""                          # -d | Enables printing all executed commands
botBackupDir=""                          # -B | Path to the bot backup directory
botUserAccount=""                        # -u | Bot user account
systemdUnitName=""                       # -s | Leave as empty string if you do NOT manage your bot with systemd
logLevel=1                               # -v | Verbose log messages. Can have value upto 3
modifiedBotFiles=(                       # -m | List of double quoted strings seperated by spaces or newlines
    "dbbackup"
) # List of modified files (relative to the bot's root) to copy to the new install. `config/botlogin.txt` and
  # `config/phantombot.db` are always included by default. Any specified with '-m' will get appended to this list.

##                            End of User Variables                           ##

##                           Do NOT edit below here!                          ##










main() {
    local true="1"
    local scriptDisplayName="PairedPrototype's PhantomBot Updater"
    local scriptName="$0"
    local scriptVersion="1.0.0"

    parseOpts "${@}"
    checkDebug

    logMessage "${scriptDisplayName} v${scriptVersion}\n"

    checkUserVars
    setupInitialVars
    checkPrerequisites
    setScriptVars

    if [[ "$isUpdateReady" ]] || [[ "$forceUpdate" ]]; then
        backupBot
        updateBot
        logMessage "Update complete!"
    else
        logMessage "There's no new update available. You may still use '-f' to force an update.\n"
    fi
}

parseOpts() {
    while getopts ":b:B:dfhm:s:Su:v" OPT; do
        case "${OPT}" in
            b)
                botPath="${OPTARG}"
                ;;
            B)
                botBackupDir="${OPTARG}"
                ;;
            d)
                set -x
                ;;
            f)
                forceUpdate="$true"
                ;;
            h)
                usage
                abortScript ""
                ;;
            m)
                modifiedBotFiles+=("${OPTARG[@]}")
                ;;
            s)
                systemdUnitName="${OPTARG}"
                ;;
            S)
                logLevel=0
                ;;
            u)
                botUserAccount="${OPTARG}"
                ;;
            v)
                ((logLevel++))
                ;;
            \?)
                usage
                abortScript "Invalid option: -${OPTARG}"
                ;;
            *)
                usage
                abortScript "Option -${OPTARG} requires a value."
                ;;
        esac
    done

    shift $((OPTIND-1))
}

usage() {
    echo "${scriptName} Help information:

    -b  Bot's path.                 Set the path of where the bot is located. A value is required.

    -B  Bot's backup directory.     By default, one directory above where the bot is i.e. /path/mycoolbot/../botbackups/

    -d  Debug.                      Forces bash to print every line it executes. Useful for reporting issues.

    -f  Force update.               Forces the update even if there isn't a new version (an effective reinstall).

    -h  Help.                       Displays this help message.

    -m  Modified files/directories. List of modified files/directories from the bot's root directory to backup and copy
                                    to the new install. A value is required, can be used multiple times.

    -s  systemd unit name.          Tells the script that the bot runs using systemd. A value is required. If specified,
                                    the bot will be restarted after the update. If this is unset, then you should
                                    shutdown your bot before proceeding as the script will have no knowledge of it's
                                    running status. If you are not sure what this is for, you probably don't need this
                                    and can shut down the bot as you normally would before running this script.

    -S Silent.                      No script generated output. However, stderr won't get redirected, so error messages
                                    from subprocess will still produce error output should one occur. 

    -u  Username.                   The user account that owns the bot files. If none specified, file operations will be
                                    run as the current user running the script. Useful for cronjobs.

    -v Verbose.                     Verbose messages. Can be specified up to 2 times.


    There is also a section named \"User variables\" at the begining of this script which you can set the defaults for
    these flags.

    Examples:
        # This is the simplest use case:
        ${scriptName} -b /home/jondoe/phantombot

        # This will reinstall PhantomBot if you're already on the latest version
        ${scriptName} -f -b /home/jondoe/phantombot
        # This is the same as above but with the options in a more compact form
        ${scriptName} -fb /home/jondoe/phantombot

        # This will ensure the specified file and directory will be copied to the new install
        ${scriptName} -b /home/jondoe/phantombot -m \"addons/ignorebots.txt\" -m \"dbbackup/\"

        # This will use the user account 'phantombot' for all file operations i.e. backing up the bot and copying the
        # \"addons/ignorebots.txt\" file to the new install. Finally, it will restart the specified service
        ${scriptName} -b /home/jondoe/phantombot -m \"addons/ignorebots.txt\" -u \"phantombot\" -s \"phantombot.service\"

        # If you have set the user variables in this script appropriately, this is an even simpler use-case
        ${scriptName}"
}

checkDebug() {
    if [[ "$debugEnabled" ]]; then
        logMessage "Debug enabled!"
        set -x
    fi
}

abortScript() {
    errorMessage="$1"
    logError "$errorMessage"
    cleanUp
    exit 1
}

requestSudoAccess() {
    local messageIfSudoPasswordNeeded="$1"
    local forceInvalidateSudo="$2"
    local isSudoAccessGranted=""

    logInfo "Checking sudo access"

    if [[ "$forceInvalidateSudo" ]]; then
        sudo -k
    fi

    sudoAccessActive=$(sudo -n echo "$true" 2> /dev/null)
    if [[ ! "$sudoAccessActive" ]]; then
        logInfo "$messageIfSudoPasswordNeeded"
    fi

    sudo -l > /dev/null && isSudoAccessGranted="$true"

    if [[ ! "$isSudoAccessGranted" ]]; then
        abortScript "Sudo access was not granted, cannot continue."
    fi
}

setupInitialVars() {
    timeStamp=$(date +"%Y-%m-%d_%H-%M-%S")
    randomString=$(tr -cd 'a-f0-9' < /dev/urandom | head -c 16)

    workingDir="/tmp/pb-${randomString}"
    doAsBotUser mkdir -p "$workingDir"

    if [[ ! "$botBackupDir" ]]; then
        botBackupDir="${botPath%/}/../botbackups"
    fi
}

checkUserVars() {
    if [[ ! "$botPath" ]]; then
        abortScript "No bot path given. Cannot continue."
    elif [[ ! -d "$botPath" ]]; then
        abortScript "The given bot path \"${botPath}\" doesn't seem to exist."
    fi

    if [[ "$botBackupDir" ]] && [[ ! -d "$botBackupDir" ]]; then
        logWarn "\"${botBackupDir}\" doesn't exist, it will be created."
        doAsBotUser mkdir -p "$botBackupDir"
    fi

    if [[ "$botUserAccount" ]]; then
        accountExists=$(id -u "$botUserAccount" > /dev/null && echo "$true")

        if [[ ! "$accountExists" ]]; then
            abortScript "The user account \"${botUserAccount}\" doesn't appear to exist."
        fi

        requestSudoAccess "sudo access is required to login as the bot user. Please grant access, otherwise the script will be terminated here."
    fi

    unitExists=$(ctlBot status > /dev/null && echo "$true")
    if [[ "$systemdUnitName" ]] && [[ ! "$unitExists" ]]; then
        abortScript "The unit \"${systemdUnitName}\" doesn't appear to exist."
    fi

    for relativeFileOrDir in "${modifiedBotFiles[@]}"; do
        modifiedFilePath="${botPath%/}/$relativeFileOrDir"
        if [[ ! -e "$modifiedFilePath" ]]; then
            abortScript "The given modified file/dir \"${modifiedFilePath}\" doesn't appear to exist"
        fi
    done
}

checkPrerequisites() {
    local aCommandDoesNotExist=""
    declare -A commandToPackageName
    commandToPackageName=(
        ["xz"]="xz-utils"
        ["unzip"]="unzip"
        ["xidel"]="debFileNotSet"
    )

    logInfo "Checking pre-requisites"

    for command in "${!commandToPackageName[@]}"; do
        command -pv "$command" > /dev/null || aCommandDoesNotExist="$true"
    done

    if [[ "$aCommandDoesNotExist" ]]; then
        logWarn "Some pre-requisites need to be installed\n"
        installPrerequisites
    fi
}

installPrerequisites() {
    local xidelDeb="${workingDir%/}/xidel_0.9.8.deb"

    commandToPackageName["xidel"]="$xidelDeb"

    packageList=$(printf ",%s" "${!commandToPackageName[@]}")
    requestSudoAccess "sudo access will be requested to install the following utilities: ${packageList/,}" "$true"
    getXidelDeb

    sudo apt-get -y install "${commandToPackageName[@]}" > /dev/null \
        && aptInstallIsSuccessful="$true"

    if [[ $aptInstallIsSuccessful ]]; then
        logInfo "Pre-requisites installed successfully"
    else
        abortScript "Failed to install all required pre-requisites. Unable to continue."
    fi
}

getXidelDeb() {
    local xidelUrl="https://github.com/benibela/xidel/releases/download/Xidel_0.9.8/xidel_0.9.8-1_i386.deb"
    local is64bit=""

    is64bit=$(uname -m | grep "x86_64" > /dev/null && echo "$true")

    if [[ $is64bit ]]; then
        xidelUrl="https://github.com/benibela/xidel/releases/download/Xidel_0.9.8/xidel_0.9.8-1_amd64.deb"
    fi

    logInfo "Fetching the xidel deb"

    curlAFile "$xidelUrl" "$xidelDeb"
}

curlAFile() {
    local urlToFetch="$1"
    local fileToSaveAs="$2"
    local curlUserString="User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/44.0.2403.89 Safari/537.36"

    doAsBotUser curl -LH "$curlUserString" "$urlToFetch" > "$fileToSaveAs" 2>/dev/null
}

setScriptVars() {
    latestPbVersion=0.0.0
    installedPbVersion=0.0.0
    getLatestVersion
    getCurrentVersion

    botName=$(basename "$botPath")
    botParentDir=$(dirname "$(readlink -f "$botPath")")
    botBackupFile=$(readlink -f "${botBackupDir%/}/${botName}-v${installedPbVersion}-${timeStamp}.tar.xz")
    modifiedBotFiles+=("config/botlogin.txt" "config/phantombot.db")

    isUpdateReady=$(isNewVersion "$latestPbVersion" "$installedPbVersion" && echo "$true")
}

getLatestVersion() {
    local pbBuildFile="${workingDir%/}/latest.xml"
    local pbLatestVersionXml="https://raw.githubusercontent.com/PhantomBot/PhantomBot/master/build.xml"

    logInfo "Fetching build.xml"

    curlAFile "$pbLatestVersionXml" "$pbBuildFile"

    latestPbVersion=$(xidel "$pbBuildFile" -e "css('property[name=version]')/@value" 2>/dev/null)
}

getCurrentVersion() {
    installedPbVersion=$(unzip -qc "${botPath%/}/PhantomBot.jar" "META-INF/MANIFEST.MF"\
        | grep -oP '(?<=Implementation-Version: )(\d+|\.)*')
}

isNewVersion() {
    local newVersion="$1"
    local oldVersion="$2"

    if [[ "$newVersion" == "$oldVersion" ]]; then
        return 1
    fi

    return 0
}

backupBot() {
    ctlBot stop

    logInfo "Backing up the bot"

    export XZ_OPT=-7T0
    doAsBotUser tar -cJf "$botBackupFile" -C "$botParentDir" "$botName"
}

doAsBotUser() {
    if [[ "$botUserAccount" ]]; then
        sudo -u "$botUserAccount" "$@" || commandFailed="$true"
    else
        "$@" || commandFailed="$true"
    fi

    if [[ "$commandFailed" ]]; then
        abortScript "Failed to execute a command"
    fi
}

updateBot() {
    local botOldName="${botPath%/}.old"
    local pbExtracted="${workingDir%/}/extracted"

    downloadNewPbUpdateAndExtract
    installNewBotVersion
    makeLaunchScriptsExecutable
    cleanUp

    ctlBot restart
}

ctlBot() {
    if [[ "$systemdUnitName" ]]; then
        local action=$1
        sudo systemctl "$action" "${systemdUnitName}"
    fi
}

downloadNewPbUpdateAndExtract() {
    local pbZipUrl="https://github.com/PhantomBot/PhantomBot/releases/download/v${latestPbVersion%/}/PhantomBot-${latestPbVersion}.zip"
    local pbZipPath="${workingDir%/}/pb-${latestPbVersion}.zip"

    logInfo "Downloading new PB version ${latestPbVersion}"

    curlAFile "${pbZipUrl}" "${pbZipPath}"
    doAsBotUser unzip -d "${pbExtracted}" "${pbZipPath}" 1>/dev/null
}

installNewBotVersion() {
    logInfo "Installing new PB version"

    doAsBotUser mv "${botPath%/}" "${botOldName%/}"
    doAsBotUser mv "${pbExtracted%/}/PhantomBot-${latestPbVersion}" "${botPath%/}"

    logInfo "Adding moving modified files to the new version"

    for fileOrDir in "${modifiedBotFiles[@]}"; do
        local fileOrDirAbsolutePath="${botOldName%/}/${fileOrDir%/}"

        ## If file, copy it. If directory copy it's contents
        if [[ -f "$fileOrDirAbsolutePath" ]]; then
            doAsBotUser cp -Pr "$fileOrDirAbsolutePath" "${botPath%/}/"
        elif [[ -d "$fileOrDirAbsolutePath" ]]; then
            doAsBotUser mkdir -p "${botPath%/}/${fileOrDir}"
            doAsBotUser cp -Pr "$fileOrDirAbsolutePath"/* "${botPath%/}/${fileOrDir}/"
        fi
    done
}

makeLaunchScriptsExecutable() {
    logInfo "Making launch scripts executable"

    doAsBotUser chmod u+x "${botPath%/}"/launch*.sh
}

cleanUp() {
    if [[ -d "$workingDir" ]] || [[ -d "$botOldName" ]]; then
        logInfo "Cleaning up the workspace"

        doAsBotUser rm -rf "$workingDir" "$botOldName"
    fi
}

logInfo() {
    local logTag="Verbose: "
    local white='\033[1;37m'
    local none='\033[0m'
    local message="$1"

    if [[ "$logLevel" -gt 2 ]]; then
        echo -e "${white}${logTag}${message}${none}"
    fi
}

logWarn() {
    local logTag="Warning: "
    local yellow='\033[1;33m'
    local none='\033[0m'
    local message="$1"

    if [[ "$logLevel" -gt 1 ]]; then
        echo -e "${yellow}${logTag}${message}${none}"
    fi
}

logError() {
    local logTag="Error: "
    local red='\033[0;31m'
    local none='\033[0m'
    local message="$1"

    if [[ "$logLevel" -gt 0 ]]; then
        echo -e "${red}${logTag}${message}${none}" >&2
    fi
}

logMessage() {
    local message="$1"

    if [[ "$logLevel" -gt 0 ]]; then
        echo -e "${message}"
    fi
}

main "${@}"
