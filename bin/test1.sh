#!/bin/bash
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd "${DIR}"
TODAY=$(date +"%Y-%m-%d")
exec 1>file-${TODAY}.out 2>&1

echo
echo directory listing
echo
ls
returncode=$?
echo
echo returncode="${returncode}"
echo

echo
echo free disk space without filebackup
echo
df -h
returncode=$?
echo
echo returncode="${returncode}"
echo

echo
echo mounting filebackup
echo
mkdir /Volumes/filebackup
mount -t smbfs //rtruell:c0c0b7d@filebackup/data /Volumes/filebackup
returncode=$?
echo
echo returncode="${returncode}"
echo

echo
echo free disk space with filebackup
echo
df -h
returncode=$?
echo
echo returncode="${returncode}"
echo

echo
echo unmounting filebackup
echo
umount /Volumes/filebackup
returncode=$?
echo
echo returncode="${returncode}"
echo

echo
echo free disk space without filebackup
echo
df -h
returncode=$?
echo
echo returncode="${returncode}"
echo

echo
echo All finished.
echo
