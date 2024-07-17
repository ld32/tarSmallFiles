#!/bin/bash

#set -x 
set -e

function unArchiveFolder() {
    cd $1
    pwd
    rm *.list.txt 2>/dev/null
    for item in `find . -maxdepth 1 -mindepth 1 | sort -V`; do 
        [ -d "$item" ] && (unArchiveFolder "$item") && continue
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
            { md5sum -c ${item%.tar}.md5sum && rm ${item%.tar}.md5sum && rm tar.done &&
            tar xf "$item" && rm "$item" && rm -r $dFolderTmp/lock.$jobID && echo tar xf "$item" | tee -a  $dFolder/unArchive.log || 
            echo Failed checksum for $item >> $dFolder/unArchive.log; } & 
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

dFolder=`realpath $dFolder`

cwd=`pwd`

echo untar start:  >> $dFolder/unArchive.log
startTime=`date`
dFolderTmp=`mktemp -d`

trap "rm -r $dFolderTmp" EXIT

pids=()   

unArchiveFolder "$dFolder"


wait

cd $cwd

echo diff -r $sFolder $dFolder | tee -a $dFolder/unArchive.log

diff -r $sFolder $dFolder | tee -a $dFolder/unArchive.log

endTime=`date`
echo "Time used: $((($(date -d "$endTime" '+%s') - $(date -d "$startTime" '+%s'))/60)) minutes"  | tee -a  $dFolder/unArchive.log
