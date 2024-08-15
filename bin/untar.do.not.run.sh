#!/bin/bash

#set -x
set -e

date
echo Running: $0 $@

core=$1
sFolder=`realpath $2`
set -x
#if [ -z $3 ]; then 
    dFolder=${sFolder#*datasets/}
    dFolder=${sFolder#*1TRaw/}
    dFolder=${dFolder//\//.X.}
    
    dFolder=`realpath $dFolder`
#else 
#    dFolder=`realpath $3`
#fi

exit

[ -d "$sFolder" ] || { echo "Usage: $0 <cores> <sourceFolder> <tarFolder>"; exit 1;  }
[ -d "$dFolder" ] || { echo "Usage: $0 <cores> <sourceFolder> <tarFolder>"; exit 1;  }

logDir=${dFolder}Log

echo untar start:  >> $logDir/unArchive.log
startTime=`date`
dFolderTmp=`mktemp -d`

trap "rm -r $dFolderTmp" EXIT

cat $logDir/folders.txt | while IFS= read -r item; do
    echo $item
    cd "$dFolder${item#$sFolder}"
    ite=`ls *.tar 2>/dev/null` || true 
    [  -z "$ite" ] && continue 
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
    
    ( md5sum -c "${ite%tar}md5sum"; tar xf "$ite" || echo Failed checksum for $ite | tee -a $logDir/unArchive.log; rm -r $ite ${ite%tar}md5sum $dFolderTmp/lock.$jobID; echo -e "$jobID `pwd`\ntar xf $ite" | tee -a  $logDir/unArchive.log;  ) & 
done

while true; do 
    current_time=$(date +%s)

    file_mod_time=$(stat -c %Y "$logDir/unArchive.log")

    time_diff=$((current_time - file_mod_time))

    [ "$time_diff" -gt 10 ] && break 
    sleep 5

done 

echo diff -r $sFolder $dFolder | tee -a $logDir/unArchive.log

diff -r $sFolder $dFolder | tee -a $logDir/unArchive.log

endTime=`date`
echo "Time used: $((($(date -d "$endTime" '+%s') - $(date -d "$startTime" '+%s'))/60)) minutes"  | tee -a  $logDir/unArchive.log
