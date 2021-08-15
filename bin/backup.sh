#!/bin/sh

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd "$DIR"
echo "Backing up Yosemite."
'/Users/rtruell/Library/Application Support/SuperDuper!/Scheduled Copies/sdautomatedcopycontroller' file://'/Users/rtruell/Library/Application Support/SuperDuper!/Saved Settings/Erase yos, then copy files from Yosemite.sdsp'
echo "Backing up ExternalHome."
'/Users/rtruell/Library/Application Support/SuperDuper!/Scheduled Copies/sdautomatedcopycontroller' file://'/Users/rtruell/Library/Application Support/SuperDuper!/Saved Settings/Erase eh, then copy files from ExternalHome.sdsp'
echo "Backing up Owncloud."
'/Users/rtruell/Library/Application Support/SuperDuper!/Scheduled Copies/sdautomatedcopycontroller' file://'/Users/rtruell/Library/Application Support/SuperDuper!/Saved Settings/Erase own, then copy files from Owncloud.sdsp'
echo "Backing up Downloads."
'/Users/rtruell/Library/Application Support/SuperDuper!/Scheduled Copies/sdautomatedcopycontroller' file://'/Users/rtruell/Library/Application Support/SuperDuper!/Saved Settings/Erase dl, then copy files from Downloads.sdsp'
echo
echo "All finished."
