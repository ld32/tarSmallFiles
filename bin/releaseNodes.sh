#!/bin/bash

#set -x

set -e


sFolder="$1"

[ ! -d "$sFolder" ] && echo Source folder not exist: $sFolder && usage

sFolder=`realpath $1`

dFolder=${sFolder#*datasets/}
#dFolder=${dFolder#*1TRaw/}
dFolder=${dFolder//\//--}
mkdir -p $dFolder

dFolder=`realpath $dFolder`    
   
logDir=${dFolder}Log

nodeFile=/n/shared_db/sbtachExclusivceLog.txt

pwd=`realpath .`
[[ "$pwd" == "/n/scratch/users/l/ld32/debug"* ]] && nodeFile=/n/scratch/users/l/ld32/debug/sbatachExclusivceLog.txt

sed -i "s/^ocompute/compute/" $nodeFile

cat  $nodeFile