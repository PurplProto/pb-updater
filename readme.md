# PairedPrototype's PhantomBot Updater

## Introduction

I host several PB chatbots for a few friends and wanted a way to easily update them. So I made this script and tried to
expand it for more general use so others could make use of this as well. And now I'm sharing it with you. 😊

## How to use

Just download the script in [releases](https://github.com/PairedPrototype/pb-updater/releases) run
`chmod u+x pb-update.sh` and then `./pb-update.sh -b /path/to/mycoolbot`. You can get help information using
`pb-update.sh -h`.

You can also edit the user variables (in your favourite text editor) at the start of the script to run with your own
defaults for the listed options.

## TODO

1. Test all the things! (may evolve restructuring the script)
1. Use the Github API to check for releases rather than the build.xml
1. Add an update checker
1. Allow user to set backup compression ratio
1. (Maybe?) Option to save user variables (use a dot file and then source it)
1. Create Contribution.md guide
