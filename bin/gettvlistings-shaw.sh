#!/bin/bash
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd "$DIR"
TODAY=$(date +"%Y-%m-%d")

echo
echo Getting TV listings
echo

# set returncode=1
# do while %returncode gt 0
#     echo xmltv.exe tv_grab_na_dd --days 14 --output .\data\%_isodate.xml --dd-data .\data\%_isodate-raw.xml
#     xmltv.exe tv_grab_na_dd --days 14 --output .\data\%_isodate.xml --dd-data .\data\%_isodate-raw.xml
#     set returncode=%errorlevel
#     echo.
#     echo return code is %returncode
#     iff %returncode ne 0 then
#         echo renaming .\data\%_isodate.xml to .\data\%_isodate-%@replace[:,-,%_time].xml
#         rename .\data\%_isodate.xml .\data\%_isodate-%@replace[:,-,%_time].xml
#     endiff
# enddo

echo time tv_grab_na_dd --days 14 --config-file ./.xmltv/tv_grab_na_dd-digital.conf --output ./tvdata/"$TODAY"-digital.xml --dd-data ./tvdata/"$TODAY"-digital-raw.xml
time tv_grab_na_dd --days 14 --config-file ./.xmltv/tv_grab_na_dd-digital.conf --output ./tvdata/"$TODAY"-digital.xml --dd-data ./tvdata/"$TODAY"-digital-raw.xml
returncode=$?
# [ "$returncode" -eq 0 ] && echo Success
# [ "$returncode" -ne 0 ] && echo Failure
echo
echo returncode="$returncode"
echo

echo time tv_grab_na_dd --days 14 --config-file ./.xmltv/tv_grab_na_dd-basic.conf --output ./tvdata/"$TODAY"-basic.xml --dd-data ./tvdata/"$TODAY"-digital-raw.xml --reprocess
time tv_grab_na_dd --days 14 --config-file ./.xmltv/tv_grab_na_dd-basic.conf --output ./tvdata/"$TODAY"-basic.xml --dd-data ./tvdata/"$TODAY"-digital-raw.xml --reprocess
returncode=$?
echo
echo returncode="$returncode"
echo

echo time tv_grab_na_dd --days 14 --config-file ./.xmltv/tv_grab_na_dd-dct700.conf --output ./tvdata/"$TODAY"-dct700.xml --dd-data ./tvdata/"$TODAY"-digital-raw.xml --reprocess
time tv_grab_na_dd --days 14 --config-file ./.xmltv/tv_grab_na_dd-dct700.conf --output ./tvdata/"$TODAY"-dct700.xml --dd-data ./tvdata/"$TODAY"-digital-raw.xml --reprocess
returncode=$?
echo
echo returncode="$returncode"
echo

echo
echo Copying the data files to fileserver
echo
cd ./tvdata
touch *
time cp * /Volumes/data/XMLTV/data

echo
echo Moving the data files to i5-3300 for MythTV
echo
time mv * /Volumes/rtruell/data

echo
echo All finished.
echo
