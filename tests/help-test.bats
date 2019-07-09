#!/usr/bin/env bats

pbUpdate="src/pb-update.sh"




@test "It displays help information" {
    run $pbUpdate -h

    printf -v stringified "%s\n" "${output[@]}"

    [[ "$status" -eq 0 ]]
    [[ "$stringified" == "$expectedHelpOutPut" ]]
}

expectedHelpOutPut="src/pb-update.sh Help information:

    -b  Bots path.                 Set the path of where the bot is located. A value is required.

    -B  Bots backup directory.     By default, one directory above where the bot is i.e. /path/mycoolbot/../botbackups/

    -d  Debug.                      Forces bash to print every line it executes. Useful for reporting issues.

    -f  Force update.               Forces the update even if there isn't a new version (an effective reinstall).

    -h  Help.                       Displays this help message.

    -m  Modified files/directories. List of modified files/directories from the bots root directory to backup and copy
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


    There is also a section named \"User variables\" at the beginning of this script which you can set the defaults for
    these flags.

    Examples:
        # This is the simplest use case:
        src/pb-update.sh -b /home/jondoe/phantombot

        # This will reinstall PhantomBot if you're already on the latest version
        src/pb-update.sh -f -b /home/jondoe/phantombot
        # This is the same as above but with the options in a more compact form
        src/pb-update.sh -fb /home/jondoe/phantombot

        # This will ensure the specified file and directory will be copied to the new install
        src/pb-update.sh -b /home/jondoe/phantombot -m \"addons/ignorebots.txt\" -m \"dbbackup/\"

        # This will use the user account 'phantombot' for all file operations i.e. backing up the bot and copying the
        # \"addons/ignorebots.txt\" file to the new install. Finally, it will restart the specified service
        src/pb-update.sh -b /home/jondoe/phantombot -m \"addons/ignorebots.txt\" -u \"phantombot\" -s \"phantombot.service\"

        # If you have set the user variables in this script appropriately, this is an even simpler use-case
        src/pb-update.sh
"
