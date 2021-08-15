#!/bin/sh

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd "$DIR"
echo "Backing up Yosemite."
open -W file://"/Users/rtruell/Library/Application Support/SuperDuper!/Saved Settings/Erase yos, then copy files from Yosemite.sdsp/Copy Job.app"
echo "Backing up ExternalHome."
open -W file://"/Users/rtruell/Library/Application Support/SuperDuper!/Saved Settings/Erase eh, then copy files from ExternalHome.sdsp/Copy Job.app"
echo "Backing up Owncloud."
open -W file://"/Users/rtruell/Library/Application Support/SuperDuper!/Saved Settings/Erase own, then copy files from Owncloud.sdsp/Copy Job.app"
echo "Backing up Downloads."
open -W file://"/Users/rtruell/Library/Application Support/SuperDuper!/Saved Settings/Erase dl, then copy files from Downloads.sdsp/Copy Job.app"
echo
echo "All finished.  Waiting 6 minutes for files to be renamed and programs to end, and then shutting down the computer."
/usr/bin/at -f ${HOME}/binsupportfiles/backup-shutdown.txt now + 6 minutes >/dev/null 2>&1
