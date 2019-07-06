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

botPath="/opt/phantombot/myCoolBot"                 # -b | Path to the bot's root directory
botName=$(basename "$botPath")                      #    | Name of the bot, directory name that contains the bot
botParentDir=$(dirname "$(readlink -f "$botPath")") #    | Full path to directory containing the bot directory
debugEnabled=""                                     # -d | Enables printing all executed commands
botBackupDir="${botParentDir}/botbackups"           # -B | Path to the bot backup directory
botUserAccount="$USER"                              # -u | Bot user account
systemdUnitName=""                                  # -s | Leave as empty string if you do NOT manage your bot with systemd
modifiedBotFiles=(
    "dbbackup"
) # List of modified files (relative to the bot's root) to copy to the new install. `config/botlogin.txt` and
  # `config/phantombot.db` are always included by default. Any specified with '-m' will get appended to this list.

##                            End of User Variables                           ##

##                           Do NOT edit below here!                          ##










main() {
    local true="1"
    local scriptDisplayName="PairedPrototype's PhantomBot Updater"
    local scriptName="$0"
    local scriptVersion=1.0

    parseOpts "${@}"
    checkDebug

    echo -e "${scriptDisplayName} v${scriptVersion}\n"

    checkUserVars
    setupInitalVars
    checkPrerequisites
    setScriptVars

    if [[ "$isUpdateReady" ]] || [[ "$forceUpdate" ]]; then
        backupBot
        updateBot
        echo -e "Update complete!\n"
    else
        echo -e "There's no new update avalible. You may still use '-f' to force an update.\n"
    fi
}

parseOpts() {
    while getopts ":b:B:dfhm:s:u:" OPT; do
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
            u)
                botUserAccount="${OPTARG}"
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
    echo -e "${scriptName} Help information:

    -b  Bot's path.                 Set the path of where the bot is located. A value is required.

    -B  Bot's backup directory.     By default it is one directory above where the bot is i.e. /path/mycoolbot/../botbackups/

    -d  Debug.                      Forces bash to print every line it executes. Useful for reporting issues.

    -f  Force update.               Forces the update even if there isn't a new version (an effective reinstall).

    -h  Help.                       Displays this help message.

    -m  Modified files/directories. List of modified files/directories from the bot's root directory to backup and copy
                                    to the new install. A value is required, can be used multiple times.

    -s  systemd unit name           Tells the script that the bot runs using systemd. A value is required. If specified,
                                    the bot will be restarted after the update. If this is unset, then you should
                                    shutdown your bot before proceeding as the script will have no knowldge of it's
                                    running status. If you are not sure what this is for, you probably don't need this
                                    and can shut down the bot as you normally would before running this script.

    -u  Username.                   The username that owns the bot files. If you are unsure, it will most likely be your
                                    user account, which means this can be left as that is assumed by default.


    There is also a section named \"User variables\" at the begining of this script which you can set the defaults for
    these flags. Then you can simply use ${scriptName}

    Examples:
        # This is the simplist use case:
        ${scriptName} -b /home/jondoe/phantombot

        # This will reinstall PhantomBot if you're already on the latest version
        ${scriptName} -f -b /home/jondoe/phantombot
        # This is the same as above but with the options in a more compact form
        ${scriptName} -fb /home/jondoe/phantombot

        # This will ensure the 2 specified file and directory will be copied to the new install
        ${scriptName} -b /home/jondoe/phantombot -m \"addons/ignorebots.txt\" -m \"dbbackup/\"

        # This will use the user account 'phantombot' for all file operations i.e. backing up and copying the \"addons/ignorebots.txt\" file and restart the specified service
        ${scriptName} -b /home/jondoe/phantombot -m \"addons/ignorebots.txt\" -u \"phantombot\" -s \"phantombot.service\"

        # Finally, if you have set the user variables appropriately, this is an even simpler usecase
        ${scriptName}"
}

checkDebug() {
    if [[ "$debugEnabled" ]]; then
        echo "Debug enabled!"
        set -x
    fi
}

abortScript() {
    errorMessage="$1"
    echo -e "$errorMessage" >&2
    cleanUp
    exit 1
}

requestSudoAccess() {
    local messageIfSudoPasswordNeeded="$1"
    local forceInvalidateSudo="$2"
    local isSudoAccessGranted=""

    if [[ "$forceInvalidateSudo" ]]; then
        sudo -k
    fi

    sudoAccessActive=$(sudo -n echo "$true" 2> /dev/null)
    if [[ ! "$sudoAccessActive" ]]; then
        echo "$messageIfSudoPasswordNeeded"
    fi

    sudo -l > /dev/null && isSudoAccessGranted="$true"

    if [[ ! "$isSudoAccessGranted" ]]; then
        abortScript "Sudo access was not granted, cannot continue."
    fi
}

setupInitalVars() {
    timeStamp=$(date +"%Y%m%d-%H%M%S")
    randomString=$(tr -cd 'a-f0-9' < /dev/urandom | head -c 16)

    workingDir="/tmp/pb-${randomString}"
    doAsBotUser mkdir "$workingDir"
}

checkUserVars() {
    if [[ ! -d "$botPath" ]]; then
        abortScript "The bot path \"${botPath}\" doesn't seem to exist"
    fi

    if [[ "$botUserAccount" ]]; then
        accountExists=$(id -u "$botUserAccount" > /dev/null && echo "$true")

        if [[ ! "$accountExists" ]]; then
            abortScript "The user account \"${botUserAccount}\" doesn't appear to exist"
        fi

        requestSudoAccess "sudo access is required to login as the bot user. Please grant access, otherwise the script will be terminated here."
    fi

    unitExists=$(ctlBot status > /dev/null && echo "$true")
    if [[ "$systemdUnitName" ]] && [[ ! "$unitExists" ]]; then
        abortScript "The unit \"${systemdUnitName}\" doesn't appear to exist"
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

    for command in "${!commandToPackageName[@]}"; do
        command -pv "$command" > /dev/null || aCommandDoesNotExist="$true"
    done

    if [[ "$aCommandDoesNotExist" ]]; then
        echo -e "Some pre-requisites need to be installed\n"
        installPrerequisites
    fi
}

installPrerequisites() {
    local xidelDeb="${workingDir}/xidel_0.9.8.deb"

    commandToPackageName["xidel"]="$xidelDeb"

    packageList=$(printf ",%s" "${!commandToPackageName[@]}")
    requestSudoAccess "sudo access will be requested to install the following utilities: ${packageList/,}" "$true"
    getXidelDeb

    sudo apt-get -y install "${commandToPackageName[@]}" > /dev/null \
        && aptInstallIsSuccessful="$true"

    if [[ $aptInstallIsSuccessful ]]; then
        echo "Pre-requisites installed truefully"
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

    curlAFile "$xidelUrl" "$xidelDeb"
}

curlAFile() {
    local urlToFetch="$1"
    local fileToSaveAs="$2"
    local curlUserString="User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/44.0.2403.89 Safari/537.36"

    doAsBotUser curl -LH "$curlUserString" "$urlToFetch" > "$fileToSaveAs" 2>/dev/null
}

setScriptVars() {
    botBackupFile="${botBackupDir%/}/${botName}-v${installedPbVersion}-${timeStamp}.tar.xz"
    modifiedBotFiles+=("config/botlogin.txt" "config/phantombot.db")

    latestPbVersion=0.0.0
    installedPbVersion=0.0.0
    getLatestVersion
    getCurrentVersion

    isUpdateReady=$(isNewVersion "$latestPbVersion" "$installedPbVersion" && echo "$true")
}

getLatestVersion() {
    local pbBuildFile="${workingDir}/latest.xml"
    local pbLatestVersionXml="https://raw.githubusercontent.com/PhantomBot/PhantomBot/master/build.xml"

    curlAFile "$pbLatestVersionXml" "$pbBuildFile"

    latestPbVersion=$(xidel "$pbBuildFile" -e "css('property[name=version]')/@value" 2>/dev/null)
}

getCurrentVersion() {
    installedPbVersion=$(unzip -qc "${botPath}/PhantomBot.jar" "META-INF/MANIFEST.MF"\
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

    doAsBotUser mkdir -P "$botBackupDir"

    doAsBotUser XZ_OPT="-6T 0" tar -cJf "$botBackupFile" -C "$botParentDir" "$botName"
}

doAsBotUser() {
    sudo -u "$botUserAccount" "$@"
}

updateBot() {
    local botOldName="${botPath}.old"
    local pbExtracted="${workingDir}/extracted"

    downloadNewPbUpdateAndExtract
    installNewBotVersion
    setCorrectOwnerOnBotDirectory
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
    local pbZipUrl="https://github.com/PhantomBot/PhantomBot/releases/download/v${latestPbVersion}/PhantomBot-${latestPbVersion}.zip"
    local pbZipPath="${workingDir}/pb-${latestPbVersion}.zip"

    curlAFile "${pbZipUrl}" "${pbZipPath}"
    doAsBotUser unzip -d "${pbExtracted}" "${pbZipPath}" 2>/dev/null
}

installNewBotVersion() {
    doAsBotUser mv "$botPath" "$botOldName"
    doAsBotUser mv "${pbExtracted}/PhantomBot-${latestPbVersion}" "${botPath}"

    for fileOrDir in "${modifiedBotFiles[@]}"; do
        local fileOrDirAbsolutePath="${botOldName%/}/${fileOrDir}"

        ## If file, copy it. If directory copy it's contents
        if [[ -f "$fileOrDirAbsolutePath" ]]; then
            doAsBotUser cp -Pr "$fileOrDirAbsolutePath" "$botPath"/
        elif [[ -d "$fileOrDirAbsolutePath" ]]; then
            doAsBotUser cp -Pr "$fileOrDirAbsolutePath"/* "$botPath"/
        fi
    done
}

setCorrectOwnerOnBotDirectory() {
    sudo chown "${botUserAccount}":"${botUserAccount}" -R "${botPath}"
    doAsBotUser chmod u+x "${botPath}"/launch*.sh
}

cleanUp() {
    if [[ -d "$workingDir" ]] || [[ -d "$botOldName" ]]; then
        sudo rm -rf "$workingDir" "$botOldName"
    fi
}

main "${@}"
