#!/bin/bash

#set -x 
#set -e

function unArchiveFolder() {
    cd $1
    pwd
    rm *.list.txt 2>/dev/null
    for item in `find . -maxdepth 1 -mindepth 1 | sort -V`; do 
        [ -d "$item" ] && ( unArchiveFolder "$item" ) && continue
        if ([[ "$item" == *tar ]]); then 
            while true; do
                jobID=0
                for i in $(seq 1 $core); do
                    if `mkdir $dFolderTmp/lock.$i 2>/dev/null`; then
                        jobID=$i
                        break
                    fi
                done
                [ "$jobID" -eq "0" ] && sleep 1 || break
            done 
            { md5sum -c ${item%.tar}.md5sum; rm ${item%.tar}.md5sum; tar xf "$item" || echo Failed checksum for $item >> $logDir/unArchive.log; rm "$item" && rm -r $dFolderTmp/lock.$jobID; echo tar xf "$item" | tee -a  $logDir/unArchive.log;  } & 
        fi
    done    
}

date
echo Running: $0 $@

core=$1
sFolder="$2"
dFolder="$3"

[ -d "$sFolder" ] || { echo "Usage: $0 <cores> <sourceFolder> <tarFolder>"; exit 1;  }
[ -d "$dFolder" ] || { echo "Usage: $0 <cores> <sourceFolder> <tarFolder>"; exit 1;  }

sFolder=`realpath $sFolder`
dFolder=`realpath $dFolder`

logDir=$dFolder-log

mkdir -p $dFolder $logDir

cwd=`pwd`

echo untar start:  >> $logDir/unArchive.log
startTime=`date`
dFolderTmp=`mktemp -d`

trap "rm -r $dFolderTmp" EXIT

unArchiveFolder "$dFolder" &

while true; do 
    current_time=$(date +%s)

    file_mod_time=$(stat -c %Y "$logDir/unArchive.log")

    time_diff=$((current_time - file_mod_time))

    [ "$time_diff" -gt 10 ] && break 
    sleep 3

done 

cd $cwd

echo diff -r $sFolder $dFolder | tee -a $logDir/unArchive.log

diff -r $sFolder $dFolder | tee -a $logDir/unArchive.log

endTime=`date`
echo "Time used: $((($(date -d "$endTime" '+%s') - $(date -d "$startTime" '+%s'))/60)) minutes"  | tee -a  $logDir/unArchive.log
