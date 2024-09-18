#!/bin/bash

set -x

set -e

function archiveFiles() {
    
    local path="$1"; path="$dFolder${path#$sFolder}"; 

    rm "$path"/*.tar "$path"/*.md5sum 2>/dev/null || true 

    #ls "$path"/*.tar && echo Tar done earlier && return

    mkdir -p "$path" || { echo Error: make folder $path | tee -a  $logDir/tarError$2.txt; }

    
    cd $1 || { echo Error: cd folder failed $1 | tee -a  $logDir/tarError$2.txt; return; } 

    local tmp=`mktemp` # && printf "%s\n" "${files[@]}" > $tmp.list

    # only file name without folder name
    local files=(`find -L . -maxdepth 1 -mindepth 1 -type f -printf "%f\n" | sort -n | tee $tmp.list`) || { echo Error: find file error for folder $1 | tee -a  $logDir/tarError$2.txt; return; } 

    # get full path 
    #local files=`find -L $1 -maxdepth 1 -mindepth 1 -type f | sort -n` ||  touch $dFolderTmp/lock.err
    
    #cat $tmp.list

    #[ -z "$files" ] && return 
    [ ${#files[@]} -eq 0 ] && return

    #files=($files) 
    #local item=$(basename ${files[0]})-$(basename ${files[-1]})

    local item=`echo ${files[0]}-${files[-1]} | sed 's/[^a-zA-Z0-9]/_/g'`

    #[ -f "$path/$item.tar" ] && echo Tar done earlier: $path/$item.tar && return

    # somehow -C and -T are not compatible, so we have to remove -C, and use full path for file list
    #tar --create --preserve-permissions --file "$tmp" -T $tmp.list -C $1 ||  touch $dFolderTmp/lock.err

    tar --create --preserve-permissions --file "$tmp" -T $tmp.list || { echo Error: tar $path | tee -a $logDir/tarError$2.txt; return; } 
    
    checkSum=$(md5sum "$tmp" | awk '{ print $1 }') || { echo Error: checksum $path | tee -a  $logDir/tarError$2.txt; return; } 
    
    echo "$checkSum $item.tar" > "$path/$item.md5sum" || { echo Error: echo $path/$item.md5sum | tee -a $logDir/tarError$2.txt; return; } 
 
    cp "$tmp" "$path/$item.tar" || { echo Error: cp .tar $path | tee -a  $logDir/tarError$2.txt; return; } 
    
    rm -r $tmp $tmp.list
}

export sFolder=/n/scratch/users/l/ld32/datasets/intersection/catmaided/1TRaw/small
export dFolder=/n/scratch/users/l/ld32/debug/intersection--catmaided--1TRaw--small
export logDir=/n/scratch/users/l/ld32/debug/intersection--catmaided--1TRaw--smallLog
jIndex=$1
echo job index: $jIndex
echo $jIndex start time $(date) $SLURM_JOBID >> /n/scratch/users/l/ld32/debug/intersection--catmaided--1TRaw--smallLog/runTime.txt
start_row=$(( (jIndex - 1) * 10 + 1 ))
end_row=$(( jIndex * 10 ))
[ $jIndex -eq 1 ] && end_row=10
sed -n "${start_row},${end_row}p" /n/scratch/users/l/ld32/debug/intersection--catmaided--1TRaw--smallLog/folders.txt
#source /home/ld32/data/tarSmallFiles1/bin/checkTarT.sh
sed -n "${start_row},${end_row}p" /n/scratch/users/l/ld32/debug/intersection--catmaided--1TRaw--smallLog/folders.txt  | while IFS= read -r line; do
  archiveFiles "$line" $jIndex
  #exit
done
echo done


exit 

# script is sourced, so only source the bash functions
[[ "${BASH_SOURCE[0]}" != "${0}" ]] && return  

usage() {
    echo "Usage: $0 <sourceFolder> <nJobs>"; exit 1;
}

date
#echo Running $0 $@ 

#set -x  

sFolder=$1

nJobs=$2

action=$3

sFolder=`realpath $1`

#if [ -z $4 ]; then 
    dFolder=${sFolder#*datasets/}

    [[ "$dFolder" == *datasets ]] && dFolder=smallFolders 

    #dFolder=${dFolder#*1TRaw/}
    dFolder=${dFolder//\//--}

    [ -f $dFolder.log ] && mv $dFolder.log $dFolder.log.$(stat -c '%.19z' $dFolder.log | cut -c 6- | tr " " . | tr ":" "-")

    dFolder=`realpath $dFolder`    
    #action="$3" 
#else 
#    dFolder=`realpath $3`
#    action=$4
#fi

[ ! -d "$sFolder" ] && echo Source folder not exist: $sFolder && usage

logDir=${dFolder}Log

mkdir -p $dFolder $logDir

touch $logDir/archive.log

dFolderTmp=`mktemp -d`

trap "rm -r $dFolderTmp" EXIT

startTime=`date`

date >> $logDir/readme
echo $USER >> $logDir/readme
echo $0 $sFolder $nScan $nJobs $action | tee -a $logDir/readme
echo $SLURM_JOB_ID


if [[ "$action" == scan ]]; then 
    
    echo Scan start `date` | tee -a $logDir/runTime.txt 
    
    #find -L "$sFolder" -type d -exec realpath {} \; | tee $dFolderTmp/folder.txt
    
    if [[ "$dFolder" == *smallFolders ]]; then
        scanSmallFolders.sh "$sFolder" 2> $logDir/scanError.txt || true 
    else  
        scanFolders.sh "$sFolder" 5 2> $logDir/scanError.txt || true 
    fi  
    echo First eight folders: >> $logDir/runTime.txt
    head -n 8 $logDir/folders.txt >> $logDir/runTime.txt
    
    echo 

    endTime=`date`

    echo Scan end $endTime | tee -a $logDir/runTime.txt 
    echo "Scan used: $((($(date -d "$endTime" '+%s') - $(date -d "$startTime" '+%s'))/60)) minutes" | tee -a >(tee -a $logDir/archive.log >> $logDir/runTime.txt)

    if [ -f $logDir/scanError.txt ]; then 
        if [ -s $logDir/scanError.txt ]; then 
            echo Scan error: && cat $logDir/scanError.txt
        else 
            rm $logDir/scanError.txt 
        fi 
    fi 
elif [[ "$action" == singleNode ]]; then 
    if [ -f $logDir/folders.txt ]; then 
        echo Folder scan is done earlier
    else     
        $(dirname $0)/tar.sh $sFolder $nScan $nJobs scan
    fi 
    echo nJobs 1 > $logDir/runTime.txt
    echo 1 start time $(date) >> $logDir/runTime.txt
    
    echo 
    echo Starting to tar using single node 
    echo 
    
    cat $logDir/folders.txt | while IFS= read -r item; do
        while true; do
            jobID=0
            for i in $(seq 1 $nJobs); do
                if `mkdir $dFolderTmp/lock.$i 2>/dev/null`; then
                    jobID=$i
                    break
                fi
            done
            [ "$jobID" -eq 0 ] && sleep 1 || break 
        done 
        
        (   echo -e "\njob $jobID\n$(date)\n$item"
            archiveFiles "$item" $jobID; 
            rm -r $dFolderTmp/lock.$jobID; 
            #echo -e "\njob $jobID\n$(date)\n$item done"
        ) &
    done 
     
    while true; do 
         ls $dFolderTmp/lock.* && sleep 30  || break 
    done 

    echo 1 end time $(date) >> $logDir/runTime.txt


    endTime=`date`
    echo "Time used: $((($(date -d "$endTime" '+%s') - $(date -d "$startTime" '+%s'))/60)) minutes" | tee -a $logDir/archive.log

    ls $logDir/tarError*.txt 2>/dev/null && exit 1

elif [[ "$action" == sbatch ]]; then 

    if [ -f $logDir/folders.txt ]; then 
        echo Folder scan is done earlier
    else     
        $(dirname $0)/tar.sh $sFolder $nScan $nJobs scan
    fi 
    x=$(wc -l < $logDir/folders.txt) 
    [ $x -lt $nJobs ] && nJobs=$x
    echo nJobs $nJobs >> $logDir/runTime.txt

    rows_per_job=$(( x / $nJobs ))
    echo "#!/bin/bash" > $logDir/array.sh 
    echo >> $logDir/array.sh 
    echo "#SBATCH -J ${dFolder##*/}._%A_%a" >> $logDir/array.sh 
    echo "#SBATCH --array=1-$nJobs" >> $logDir/array.sh 
    echo "#SBATCH --output=$logDir/slurm_%A_%a.out" >> $logDir/array.sh
    echo >> $logDir/array.sh
    echo "set -e" >> $logDir/array.sh 
    echo "echo job index: \$SLURM_ARRAY_TASK_ID" >> $logDir/array.sh 
    echo "echo \$SLURM_ARRAY_TASK_ID start time \$(date) \$SLURM_JOBID >> $logDir/runTime.txt" >> $logDir/array.sh
    echo "export sFolder=$sFolder" >> $logDir/array.sh
    echo "export dFolder=$dFolder" >> $logDir/array.sh
    echo "export logDir=$logDir" >> $logDir/array.sh

    echo "start_row=\$(( (SLURM_ARRAY_TASK_ID - 1) * $rows_per_job + 1 ))" >> $logDir/array.sh 
    echo "end_row=\$(( SLURM_ARRAY_TASK_ID * $rows_per_job ))"  >> $logDir/array.sh 
    echo "[ \$SLURM_ARRAY_TASK_ID -eq $nJobs ] && end_row=$x"  >> $logDir/array.sh 
    echo "sed -n \"\${start_row},\${end_row}p\" $logDir/folders.txt " >> $logDir/array.sh
    echo "source $0" >> $logDir/array.sh
    echo "sed -n \"\${start_row},\${end_row}p\" $logDir/folders.txt  | while IFS= read -r line; do" >> $logDir/array.sh 
    #echo "  cd \$line || continue" >> $logDir/array.sh
    #echo "  mkdir -p $dFolder\${line#$sFolder}" >> $logDir/array.sh
    echo "  archiveFiles \"\$line\" \$SLURM_ARRAY_TASK_ID" >> $logDir/array.sh     
    #echo "  archiveFiles $dFolder\${line#$sFolder} \$SLURM_ARRAY_TASK_ID" >> $logDir/array.sh 
    #echo "  exit" >> $logDir/array.sh
    echo done >> $logDir/array.sh 
    echo echo done >> $logDir/array.sh
    echo "echo \$SLURM_ARRAY_TASK_ID end time \$(date) \$SLURM_JOBID >> $logDir/runTime.txt" >> $logDir/array.sh
    
    echo "echo -e \"Subject: ${dFolder##*/}/a\$SLURM_ARRAY_TASK_ID/\$SLURM_JOBID is done\n\`summarizeRun.sh $dFolder\`\" | sendmail `head -n 1 ~/.forward` " >> $logDir/array.sh
    echo sleep 10  >> $logDir/array.sh # wait for email to send out
    echo "[ -f $logDir/tarError\$SLURM_ARRAY_TASK_ID.txt ] && exit 1" >> $logDir/array.sh 

    echo Slurm script ready: $logDir/array.sh
    #cat $logDir/array.sh
    
    echo sbatch -A rccg -t 12:0:0 -p short --mem 4G $logDir/array.sh
    output=`sbatch -A rccg  -t 12:0:0 -p short --mem 4G $logDir/array.sh`
    echo ${output##* } >> $logDir/allJobs.txt

    echo Submitted job ${output##* } >> $logDir/runTime.txt
    echo $output

    # for i in `seq 2 $nJobs`; do 
    #     scontrol update jobid=${output##* }_$i jobname=${dFolder##*/}.${output##* }_$i 
    # done     

    endTime=`date`
    echo "Time used: $((($(date -d "$endTime" '+%s') - $(date -d "$startTime" '+%s'))/60)) minutes" | tee -a $logDir/archive.log

    [ -f $logDir/scanError.txt ] && exit 1 

elif [[ "$action" == esbatch ]]; then 

    notDone=''
    if [ -f $logDir/allJobs.txt ]; then 
        IFS=$'\n'; out=`squeue -u $USER -t PD,R -o "%.18i"`
        if [ ! -z "$out" ]; then 
            for line in `cat $logDir/allJobs.txt`; do
                [[ "$out" == *$line* ]] && notDone="$line $notDone"
            done 
        fi     
    fi 

    [ -z "$notDone" ] || { echo -e "A run was started earlier on the folder and the folowing jobs are still pending or running\nPlease wait for them to finish or cancel them:\n$notDone"; exit 1; }

    # if this is a rerun, use old nJobs
    if [ -f $logDir/runTime.txt ]; then 
        x=`grep "^nJobs " $logDir/runTime.txt | tail -n1`
        x=${x#* }; 
        [ ! -z "$x" ] && nJobs=$x || echo nJobs $nJobs >> $logDir/runTime.txt
        cp $logDir/runTime.txt $logDir/runTime.txt.back
    else 
        echo nJobs $nJobs >> $logDir/runTime.txt
    fi

    rm -r $logDir/exclusive $logDir/allJobs.txt  2>/dev/null || true 

    if [ -f $logDir/folders.txt ]; then 
        echo Folder scan is done earlier
    else     
        $(dirname $0)/tar.sh $sFolder $nScan $nJobs scan 
    fi 

    [ -f $logDir/runTime.txt ] && cp $logDir/runTime.txt $logDir/runTime.txt.back

    x=$(wc -l < $logDir/folders.txt)  
    [ $x -lt $nJobs ] && nJobs=$x
    echo nJobs $nJobs >> $logDir/runTime.txt

    nodeFile=$logDir/sbtachExclusivceLog.txt

    #nodeFile=/n/data3_vast/data3_datasets/ld32/sbatachExclusivceLog.txt
    
    [[ "`realpath .`" == "/n/scratch/users/l/ld32/debug"* ]] && nodeFile=/n/scratch/users/l/ld32/debug/sbatachExclusivceLog.txt

    sinfo -p medium -N -o "%N %P %T" | grep -v drain | grep -v down | grep -v allocated | grep -v "\-h\-" | cut -d ' ' -f 1,2 > $nodeFile
    
    #[[ "$PWD" == "/n/scratch/users/l/ld32/debug"* ]] && nodeFile=/n/scratch/users/l/ld32/debug/sbatachExclusivceLog.txt

    rows_per_job=$(( x / $nJobs ))
    
    echo "#!/bin/bash" > $logDir/job.sh   
    echo >> $logDir/job.sh
    echo "set -e" >> $logDir/job.sh 
    
    echo "export sFolder=$sFolder" >> $logDir/job.sh
    echo "export dFolder=$dFolder" >> $logDir/job.sh
    echo "export logDir=$logDir" >> $logDir/job.sh
    
    echo "trap \"rm -r \$logDir/exclusive 2>/dev/null; echo exiting and delete lock; \" EXIT" >> $logDir/job.sh

    echo "jIndex=\$1" >> $logDir/job.sh
    echo "echo job index: \$jIndex" >> $logDir/job.sh
    echo "echo \$jIndex start time \$(date) \$SLURM_JOBID >> $logDir/runTime.txt" >> $logDir/job.sh
    echo "start_row=\$(( (jIndex - 1) * $rows_per_job + 1 ))" >> $logDir/job.sh 
    echo "end_row=\$(( jIndex * $rows_per_job ))"  >> $logDir/job.sh 
    echo "[ \$jIndex -eq $nJobs ] && end_row=$x"  >> $logDir/job.sh 
    echo "sed -n \"\${start_row},\${end_row}p\" $logDir/folders.txt " >> $logDir/job.sh
    echo "source $0" >> $logDir/job.sh
    echo "sed -n \"\${start_row},\${end_row}p\" $logDir/folders.txt  | while IFS= read -r line; do" >> $logDir/job.sh         
    echo "  archiveFiles \"\$line\" \$jIndex" >> $logDir/job.sh 
    echo done >> $logDir/job.sh 
    echo echo done >> $logDir/job.sh
    
    echo "echo \$jIndex end time \$(date) \$SLURM_JOBID >> $logDir/runTime.txt" >> $logDir/job.sh 
    
    echo "if [ -f $logDir/tarError\$jIndex.txt ]; then" >> $logDir/job.sh 
    echo "  er=\`cat $logDir/tarError\$jIndex.txt\`" >> $logDir/job.sh
    echo "  echo -e \"Subject: !!! With error: s\$jIndex/\$SLURM_JOBID done ${dFolder##*/}\nPlase check: \$er\" | sendmail `head -n 1 ~/.forward` " >> $logDir/job.sh
    echo "else" >> $logDir/job.sh 
    echo "  echo -e \"Subject: s\$jIndex/\$SLURM_JOBID done ${dFolder##*/}\" | sendmail `head -n 1 ~/.forward` " >> $logDir/job.sh
    echo "fi" >> $logDir/job.sh 
    # remove later
    #echo "sleep 35" >> $logDir/job.sh 

    echo "while ! mkdir $logDir/exclusive 2>/dev/null; do" >> $logDir/job.sh 
    #echo "  echo waiting for the lock" >>  $logDir/job.sh 
    echo "  sleep \$((1 + RANDOM % 10))" >> $logDir/job.sh 
    echo "done" >> $logDir/job.sh 

    echo "echo got the lock" >>  $logDir/job.sh 

    #echo "echo job $jIndex original sbtachExclusivceLog.txt: >&2" >> $logDir/job.sh
    #echo "cat $nodeFile >&2" >> $logDir/job.sh 

    echo "sed -i \"s/^o\${SLURM_JOB_NODELIST}/\${SLURM_JOB_NODELIST}/\" $nodeFile" >> $logDir/job.sh 
    echo "sed -i \"s/spaceHolder\${SLURM_JOB_ID}/; done \$(date '+%m-%d %H:%M:%S')/\" $nodeFile" >> $logDir/job.sh  

    # release holding job
    echo "IFS=$'\n'" >> $logDir/job.sh 
    echo "for line in \`grep '^hold' $nodeFile | grep -v unhold\`; do " >> $logDir/job.sh 
    echo "  job=\${line##* }; p=\`echo \$line | cut -d' ' -f2\`" >> $logDir/job.sh 
    echo "  node=\`grep '^com' $nodeFile | grep \$p | shuf -n 1 | tr -s \" \" | cut -f1 | cut -d' ' -f1\`" >> $logDir/job.sh 
    echo "  if [ -z \"\$node\" ]; then " >> $logDir/job.sh 
    echo "      break" >> $logDir/job.sh 
    echo "  else " >> $logDir/job.sh 
    echo "      scontrol update JobID=\$job NodeList=\$node" >> $logDir/job.sh 
    echo "      scontrol release JobID=\$job" >> $logDir/job.sh 
    echo "      sed -i \"s/^\${node}/o\${node}/\" $nodeFile" >> $logDir/job.sh 
    echo "      sed -i \"s/\${job}/\${job}; unhold onto: \$node by job: \${SLURM_JOB_ID} \$(date '+%m-%d %H:%M:%S')spaceHolder\${job}/\" $nodeFile" >> $logDir/job.sh  
    echo "  fi " >> $logDir/job.sh 
    #echo "  echo job $jIndex updated sbtachExclusivceLog.txt: >&2" >> $logDir/job.sh 
    #echo "  cat $nodeFile >&2" >> $logDir/job.sh 
    echo "done " >> $logDir/job.sh 

    # switch nodes for jobs penidng more than x seconds
    echo "pending=\`squeue -u $USER -t PD -o \"%.18i\"\`" >> $logDir/job.sh 
    echo "if [ ! -z \"\$pending\" ]; then" >> $logDir/job.sh  
    echo "  for line in \`grep spaceHolder $nodeFile\`; do " >> $logDir/job.sh 
    echo "      job=\${line##*spaceHolder}; p=\`echo \$line | cut -d' ' -f2\`" >> $logDir/job.sh 
     
    # submit medium 08-07 14:34:37 job: 43540546 on: compute-a-16-35spaceHolder43540546
    echo "      t=\${line##submit medium }; t=\${t% job*}; t=\$(date -d \"\$t\" +%s)" >> $logDir/job.sh 
    echo "      ct=\$(date +%s); pt=\$((ct - t)); jIndex=\${line#*job }; jIndex=\${jIndex%%:*}" >> $logDir/job.sh 
    
                # pending for more than x seconds
    echo "      if [ \"\$pt\" -gt 1200 ] && [[ "\$pending" == *\$job* ]]; then" >> $logDir/job.sh 
    echo "          node=\`grep '^com' $nodeFile | grep \$p | shuf -n 1 | tr -s \" \" | cut -f1 | cut -d' ' -f1\`" >> $logDir/job.sh 
    echo "          if [ -z \"\$node\" ]; then " >> $logDir/job.sh 
    echo "              break" >> $logDir/job.sh 
    echo "          else " >> $logDir/job.sh 
    echo "              scancel \$job" >> $logDir/job.sh
    echo "              cmd=\"sbatch -A rccg --qos=testbump -w \$node -o $logDir/slurm.\$jIndex.1.txt -J ${dFolder##*/}.\$jIndex.1 -t 48:0:0 -p medium --mem 2G $logDir/job.sh \$jIndex\" " >> $logDir/job.sh 
    echo "              output=\"\$(eval \$cmd)\" " >> $logDir/job.sh 
    echo "              sed -i \"s/^\${node}/o\${node}/\" $nodeFile " >> $logDir/job.sh 
    echo "              echo submit medium \`date '+%Y-%m-%d %H:%M:%S'\` job \$jIndex: \${output##* } on: \${node}spaceHolder\${output##* } >> $nodeFile" >> $logDir/job.sh 
    echo "              echo \${output##* } >> $logDir/allJobs.txt" >> $logDir/job.sh 
    echo "              echo submitted \${output##* }/\$jIndex on \$node >> $logDir/runTime.txt" >> $logDir/job.sh 

    echo "              echo resumit to switch node for \$job to \$node" >> $logDir/job.sh 
    #echo "             scontrol update JobID=\$job NodeList=\$node" >> $logDir/job.sh 
    #echo "             scontrol release JobID=\$job" >> $logDir/job.sh 
    echo "              sed -i \"s/^\${node}/o\${node}/\" $nodeFile" >> $logDir/job.sh # don't release it because job pending forever!!
    echo "              sed -i \"s/spaceHolder\${job}/\${job}, pended too long, resumit as \${output##* } on: \$node by job: \${SLURM_JOB_ID}/\" $nodeFile" >> $logDir/job.sh  
    echo "          fi" >> $logDir/job.sh
    echo "      fi" >> $logDir/job.sh 
    #echo "      echo job $jIndex updated sbtachExclusivceLog.txt: >&2" >> $logDir/job.sh 
    #echo "      cat $nodeFile >&2" >> $logDir/job.sh 
    echo "  done " >> $logDir/job.sh 
    echo "fi" >> $logDir/job.sh

    echo "rm -r $logDir/exclusive " >> $logDir/job.sh 
    
    echo "echo released the lock" >>  $logDir/job.sh 

    echo sleep 10 >> $logDir/job.sh # wait for email to send out
    
    echo "[ -f $logDir/tarError\$jIndex.txt ] && exit 1" >> $logDir/job.sh 
    
    echo Slurm script:
    echo Slurm script ready: $logDir/job.sh
    
    for i in `seq 1 $nJobs`; do 

        # if done earler, skip it
        grep "^$i end time" $logDir/runTime.txt && echo Done earlier && continue         
        
        node=`grep '^com' $nodeFile | grep medium | shuf -n 1 | tr -s " " | cut -f1 | cut -d' ' -f1`
        
        #node=compute-a-16-21

        if [ -z "$node" ]; then
            cmd="sbatch -A rccg --qos=testbump -o $logDir/slurm.$i.txt -J ${dFolder##*/}.$i -t 48:0:0 -H -p medium --mem 2G $logDir/job.sh $i" 
            echo Submitting job:
            echo $cmd | tee -a $logDir/readme
            output="$(eval $cmd)"
            echo $output
            echo holdit medium `date '+%m-%d %H:%M:%S'` job $i: ${output##* } >> $nodeFile
            echo ${output##* } >> $logDir/allJobs.txt
            echo submitted ${output##* }/$i >> $logDir/runTime.txt
        else
            cmd="sbatch -w $node --qos=testbump -c 1 -A rccg -o $logDir/slurm.$i.txt -J ${dFolder##*/}.$i -t 48:0:0 -p medium --mem 2G $logDir/job.sh $i" 
            echo Submitting job:
            echo $cmd | tee -a $logDir/readme
            output="$(eval $cmd)"
            echo $output
            sed -i "s/^${node}/o${node}/" $nodeFile
            echo submit medium `date '+%Y-%m-%d %H:%M:%S'` job $i: ${output##* } on: ${node}spaceHolder${output##* } >> $nodeFile
            echo ${output##* } >> $logDir/allJobs.txt
            echo submitted ${output##* }/$i on $node >> $logDir/runTime.txt
        fi
    
        sleep 1
    done
    cat $nodeFile >&2

    endTime=`date`
    echo "Time used: $((($(date -d "$endTime" '+%s') - $(date -d "$startTime" '+%s'))/60)) minutes" | tee -a $logDir/archive.log

    if [ -f $logDir/scanError.txt ]; then 
        echo Sending scan fail email...
        echo -e "Subject: !!! Scan error: $dFolder\nPlease check: $logDir/scanError.txt\n`cat $logDir/scanError.txt`" | sendmail `head -n 1 ~/.forward`
        exit 1 
    fi
else 
    echo action wrong: $action; usage;
fi
