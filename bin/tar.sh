#!/bin/bash

#set -x
set -e

function tarFiles() {
    local files="${1#\\n}"                           # remove leading \n

    local item="${files%%\\n*}-${files##*\\n}"       # firstFile-lastFile

    [ -f "$2/$item.tar" ] && echo Tar done earlier: $2/$item.tar && return
    
    pattern="/[^ ]*/"
    
    local tmp=`mktemp` && echo -e "$files" > $tmp.list
    tar --create --preserve-permissions --file "$tmp" -T $tmp.list &&
    mv "$tmp"  "$2/$item.tar" && result=`md5sum "$2/$item.tar"` && echo "${result//$pattern/}" > $2/$item.md5sum && rm $tmp.list &&
    echo -e "\njob $3\n$(date)\ncd `pwd`\ntar --create --preserve-permissions --file $2/$item.tar -T $tmp.list" | tee -a $logDir/archive.log
}

function archiveFiles() {
    [ -f "$logDir/${1//\/}.done" ] && echo Tar done earlier for folder: $1 && return
     
    local files=""
    local totalSize=0
    local line="" 
    for line in `find -L . -maxdepth 1 -mindepth 1 -type f -printf "%f----%k\n" | sort -n`; do  # %f file name, %k file size
        local item=${line%----*}

        local size=${line#*----}

        [ "$size" -gt "1048576" ] && echo cp "$item" "$1" && cp "$item" "$1" && continue # bigger than 1G, inore it
        files="$files\n$item"

        totalSize=$((totalSize + size))

        if [ "$totalSize" -gt "1048576" ]; then # bigger than 1G
            tarFiles "$files" "$1" $2
            files=""
            totalSize=0
        fi
    done
    if [ ! -z "$files" ]; then
        tarFiles "$files" "$1" $2
    fi
    touch "$logDir/${1//\/}.done" 
}

function archiveFolder() {
    
    cd $1 || { echo Error: folder not accessible, ignore it: `pwd`/$1 && return; }

    mkdir -p "$2"
    
    local line="" 
    for line in `find -L . -maxdepth 1 -mindepth 1 -type d -printf "%f\n" | sort -n`; do
        ( archiveFolder $line "$2/$line" )
    done

    if [[ "$action" == singleNode ]]; then 
    #    echo $(pwd)
    #else
        while true; do
            local jobID=0
            if { set -C; 2>/dev/null >$dFolderTmp/lock.0; }; then
                for i in $(seq 1 $nJobs); do
                    if [ ! -f $dFolderTmp/lock.$i ]; then
                        touch $dFolderTmp/lock.$i
                        jobID=$i  
                        break
                    fi
                done
                rm -f $dFolderTmp/lock.0
            fi
            [ "$jobID" -eq "0" ] && sleep 0.01 || break

        done
        (archiveFiles "$2" $jobID && rm -f $dFolderTmp/lock.$jobID) &     
    fi     
}

# script is sourced, so only source the bash functions
[[ "${BASH_SOURCE[0]}" != "${0}" ]] && return  

date
echo Running: $0 $@

nJobs=$1

sFolder=`realpath $2`

dFolder=`realpath $3`

action="$4" 

usage() {
    echo "Usage: $0 <nJobs> <sourceFolder> <destinationFolder> <action: singleNode/scan/sbatch/esbatch>"; exit 1;
}

[ ! -d "$sFolder" ] && echo Source folder not exist: $sFolder && usage

logDir=${dFolder}Log

mkdir -p $dFolder $logDir

date >> $dFolder/readme
echo $USER >> $dFolder/readme
echo $0 $nJobs $sFolder $dFolder $action >>  $dFolder/readme

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

rm -r $logDir/exclusive $logDir/allJobs.txt  2>/dev/null || true 

dFolderTmp=`mktemp -d`

trap "rm -r $dFolderTmp" EXIT

startTime=`date`

if [[ "$action" == scan ]]; then 
    
    echo Scan start `date` | tee -a $logDir/runTime.txt 
    
    find -L "$sFolder" -type d -exec realpath {} \; | tee $dFolderTmp/folder.txt
    
    mv $dFolderTmp/folder.txt $logDir/folders.txt
    
    cat $logDir/folders.txt >> $logDir/runTime.txt

    echo Scan end `date` | tee -a $logDir/runTime.txt 
     
elif [[ "$action" == singleNode ]]; then    
    echo nJobs 1 > $logDir/runTime.txt
    echo 1 start time $(date) >> $logDir/runTime.txt
    archiveFolder "$sFolder" "$dFolder"
    

    while true; do   
        if [ -f $logDir/archive.log ]; then 
            current_time=$(date +%s)
            file_mod_time=$(stat -c %Y "$logDir/archive.log")

            time_diff=$((current_time - file_mod_time))

            [ "$time_diff" -gt 60 ] && break 
        fi
        sleep 30
    done
    echo 1 end time $(date) >> $logDir/runTime.txt

elif [[ "$action" == sbatch ]]; then 
    [ ! -f $logDir/folders.txt ] && $(dirname $0)/tar.sh 1 $sFolder $dFolder scan || echo Folder scan is done earlier

    x=$(wc -l < $logDir/folders.txt) 
    [ $x -lt $nJobs ] && nJobs=$x
    echo nJobs $nJobs >> $logDir/runTime.txt

    rows_per_job=$(( x / $nJobs ))
    echo "#!/bin/bash" > $logDir/array.sh 
    echo >> $logDir/array.sh 
    echo "#SBATCH -J ${dFolder##*/}._%A_%a" >> $logDir/array.sh 
    echo "#SBATCH --array=1-$nJobs" >> $logDir/array.sh 
    echo "#SBATCH --output=$logDir/slurm_%A_%a.out" >> $logDir/array.sh  
    echo "#SBATCH --error=$logDir/slurm_%A_%a.out" >> $logDir/array.sh  
    echo >> $logDir/array.sh
    echo "set -e" >> $logDir/array.sh 
    echo "echo job index: \$SLURM_ARRAY_TASK_ID" >> $logDir/array.sh 
    echo "echo \$SLURM_ARRAY_TASK_ID start time \$(date) \$SLURM_JOBID >> $logDir/runTime.txt" >> $logDir/array.sh
    echo dFolder=$dFolder >> $logDir/array.sh
    echo logDir=$logDir >> $logDir/array.sh

    echo "start_row=\$(( (SLURM_ARRAY_TASK_ID - 1) * $rows_per_job + 1 ))" >> $logDir/array.sh 
    echo "end_row=\$(( SLURM_ARRAY_TASK_ID * $rows_per_job ))"  >> $logDir/array.sh 
    echo "[ \$SLURM_ARRAY_TASK_ID -eq $nJobs ] && end_row=$x"  >> $logDir/array.sh 
    echo "sed -n \"\${start_row},\${end_row}p\" $logDir/folders.txt " >> $logDir/array.sh
    echo "source $0" >> $logDir/array.sh
    echo "sed -n \"\${start_row},\${end_row}p\" $logDir/folders.txt  | while IFS= read -r line; do" >> $logDir/array.sh 
    echo "  cd \$line || continue" >> $logDir/array.sh
    echo "  mkdir -p $dFolder\${line#$sFolder}" >> $logDir/array.sh
        
    echo "  archiveFiles $dFolder\${line#$sFolder} \$SLURM_ARRAY_TASK_ID" >> $logDir/array.sh 
    #echo "  exit" >> $logDir/array.sh
    echo done >> $logDir/array.sh 
    echo echo done >> $logDir/array.sh
    echo "echo \$SLURM_ARRAY_TASK_ID end time \$(date) \$SLURM_JOBID >> $logDir/runTime.txt" >> $logDir/array.sh

    echo "echo -e \"Subject: ${dFolder##*/}/\$SLURM_ARRAY_TASK_ID is done\n\`summarizeRun.sh $dFolder\`\" | sendmail `head -n 1 ~/.forward` " >> $logDir/array.sh
    echo sleep 10  >> $logDir/array.sh # wait for email to send out

    echo Slurm script:
    cat $logDir/array.sh
    
    #export SLURM_ARRAY_TASK_ID=1
    #sh $dFolder/array.sh
    #[[ "$SLURM_CLUSTER_NAME" = o2-dev ]] && acc="-A rccg"
    echo sbatch -A rccg -t 12:0:0 -p short --mem 4G $logDir/array.sh
    output=`sbatch --requeue -A rccg  -t 12:0:0 -p short --mem 4G $logDir/array.sh`
    echo ${output##* } >> $logDir/allJobs.txt

    echo Submitted job ${output##* } >> $logDir/runTime.txt
    echo $output

elif [[ "$action" == esbatch ]]; then 
    [ ! -f $logDir/folders.txt ] && $(dirname $0)/tar.sh 1 $sFolder $dFolder scan || echo Folder scan is done earlier

    x=$(wc -l < $logDir/folders.txt)  
    [ $x -lt $nJobs ] && nJobs=$x
    echo nJobs $nJobs >> $logDir/runTime.txt

    rows_per_job=$(( x / $nJobs ))
    
    echo "#!/bin/bash" > $logDir/job.sh   
    echo >> $logDir/job.sh
    echo "set -e" >> $logDir/job.sh 
    echo "jIndex=\$1" >> $logDir/job.sh
    echo "echo job index: \$jIndex" >> $logDir/job.sh 
    echo "echo \$jIndex start time \$(date) \$SLURM_JOBID >> $logDir/runTime.txt" >> $logDir/job.sh 
    echo dFolder=$dFolder >> $logDir/job.sh
    echo logDir=$logDir >> $logDir/job.sh
    echo "start_row=\$(( (jIndex - 1) * $rows_per_job + 1 ))" >> $logDir/job.sh 
    echo "end_row=\$(( jIndex * $rows_per_job ))"  >> $logDir/job.sh 
    echo "[ \$jIndex -eq $nJobs ] && end_row=$x"  >> $logDir/job.sh 
    echo "sed -n \"\${start_row},\${end_row}p\" $logDir/folders.txt " >> $logDir/job.sh
    echo "source $0" >> $logDir/job.sh
    echo "sed -n \"\${start_row},\${end_row}p\" $logDir/folders.txt  | while IFS= read -r line; do" >> $logDir/job.sh 
    echo "  cd \$line || continue" >> $logDir/job.sh
    echo "  mkdir -p $dFolder\${line#$sFolder}" >> $logDir/job.sh
        
    echo "  archiveFiles $dFolder\${line#$sFolder} \$jIndex" >> $logDir/job.sh 
    #echo "  exit" >> $logDir/job.sh
    echo done >> $logDir/job.sh 
    echo echo done >> $logDir/job.sh
    
    echo "echo \$jIndex end time \$(date) \$SLURM_JOBID >> $logDir/runTime.txt" >> $logDir/job.sh 
    
    echo "echo -e \"Subject: ${dFolder##*/}/\$jIndex/\$SLURM_JOBID is done\n\`summarizeRun.sh $dFolder\`\" | sendmail `head -n 1 ~/.forward` " >> $logDir/job.sh
    
    echo "while ! mkdir $logDir/exclusive 2>/dev/null; do" >> $logDir/job.sh 
    echo "  sleep \$((1 + RANDOM % 10))" >> $logDir/job.sh 
    echo "done" >> $logDir/job.sh 
    echo "echo job $jIndex original sbtachExclusivceLog.txt: >&2" >> $logDir/job.sh
    echo "cat /n/shared_db/sbtachExclusivceLog.txt >&2" >> $logDir/job.sh 

    echo "sed -i \"s/^o\${SLURM_JOB_NODELIST}/\${SLURM_JOB_NODELIST}/\" /n/shared_db/sbtachExclusivceLog.txt" >> $logDir/job.sh 
    echo "sed -i \"s/spaceHolder\${SLURM_JOB_ID}/; done \$(date '+%m-%d %H:%M:%S')/\" /n/shared_db/sbtachExclusivceLog.txt" >> $logDir/job.sh  

    #echo "set -x " >> $logDir/job.sh 
    echo "IFS=$'\n'" >> $logDir/job.sh 
    echo "for line in \`grep '^hold' /n/shared_db/sbtachExclusivceLog.txt | grep -v unhold\`; do " >> $logDir/job.sh 
    echo "  job=\${line##* }; p=\`echo \$line | cut -d' ' -f2\`" >> $logDir/job.sh 
    echo "  node=\`grep '^com' /n/shared_db/sbtachExclusivceLog.txt | grep \$p | head -n1 | tr -s \" \" | cut -f1 | cut -d' ' -f1\`" >> $logDir/job.sh 
    echo "  if [ -z \"\$node\" ]; then " >> $logDir/job.sh 
    echo "      break" >> $logDir/job.sh 
    echo "  else " >> $logDir/job.sh 
    echo "      scontrol update JobID=\$job NodeList=\$node" >> $logDir/job.sh 
    echo "      scontrol release JobID=\$job" >> $logDir/job.sh 
    echo "      sed -i \"s/^\${node}/o\${node}/\" /n/shared_db/sbtachExclusivceLog.txt" >> $logDir/job.sh 
    echo "      sed -i \"s/\${job}/\${job}; unhold onto: \$node by job: \${SLURM_JOB_ID} \$(date '+%m-%d %H:%M:%S')spaceHolder\${job}/\" /n/shared_db/sbtachExclusivceLog.txt" >> $logDir/job.sh  
    echo "  fi " >> $logDir/job.sh 
    echo "  echo job $jIndex updated sbtachExclusivceLog.txt: >&2" >> $logDir/job.sh 
    echo "  cat /n/shared_db/sbtachExclusivceLog.txt >&2" >> $logDir/job.sh 
    echo "done " >> $logDir/job.sh 
    echo "rm -r $logDir/exclusive " >> $logDir/job.sh 
    echo sleep 10 >> $logDir/job.sh # wait for email to send out
    
    echo Slurm script:
    cat $logDir/job.sh 
    
    [ -f /n/shared_db/sbtachExclusivceLog.txt ] || sinfo -p short -N -o "%N %P %T" | grep -v drain | grep -v down | grep -v allocated | cut -d ' ' -f 1,2 > /n/shared_db/sbtachExclusivceLog.txt
    
    #set -x 
    for i in `seq 1 $nJobs`; do 
        
        #cmd="sh $logDir/job.sh $p 0" 
        node=`grep '^com' /n/shared_db/sbtachExclusivceLog.txt | grep short | head -n1 | tr -s " " | cut -f1 | cut -d' ' -f1`
        
        if [ -z "$node" ]; then
            cmd="sbatch -A rccg --requeue -o $logDir/slurm.$i.txt -J ${dFolder##*/}.$i -t 12:0:0 -H -p short --mem 2G $logDir/job.sh $i" 
            echo Submitting job:
            echo $cmd 
            output="$(eval $cmd)"
            #scontrol hold ${output##* }
            echo holdit short `date '+%m-%d %H:%M:%S'` job: ${output##* } >> /n/shared_db/sbtachExclusivceLog.txt
            echo ${output##* } >> $logDir/allJobs.txt
            echo submitted ${output##* }/$i >> $logDir/runTime.txt
        else
            cmd="sbatch -w $node --requeue -A rccg -o $logDir/slurm.$i.txt -J ${dFolder##*/}.$i -t 12:0:0 -p short --mem 2G $logDir/job.sh $i" 
            echo Submitting job:
            echo $cmd 
            output="$(eval $cmd)"
            sed -i "s/^${node}/o${node}/" /n/shared_db/sbtachExclusivceLog.txt
            echo submit short `date '+%m-%d %H:%M:%S'` job: ${output##* } on: ${node}spaceHolder${output##* } >> /n/shared_db/sbtachExclusivceLog.txt
            echo ${output##* } >> $logDir/allJobs.txt
            echo submitted ${output##* }/$i on $node >> $logDir/runTime.txt
        fi
    done
    cat /n/shared_db/sbtachExclusivceLog.txt >&2

else 
    echo action wrong: $action; usage;
fi

endTime=`date`

echo "Time used: $((($(date -d "$endTime" '+%s') - $(date -d "$startTime" '+%s'))/60)) minutes" | tee -a $logDir/archive.log
