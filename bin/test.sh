#!/bin/bash
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd "$DIR"

rmount Test
ls /Volumes/Test
rmount Test

#read -n1 -r -p "Press any key to continue..."
