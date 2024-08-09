#!/bin/bash

#set -x 

[ -f ${1}Log/runTime.txt ] || { echo Runtime file not exist: ${1}Log/runTime.txt; echo Usage: $0 destinationFolder; exit; }

echo checking log: `realpath ${1}Log/runTime.txt`, file content:
cat ${1}Log/runTime.txt

echo 

echo Run summary:

# Initialize an associative array to store start times
declare -A start_times
declare -A job_runtimes

# Initialize a variable to store the total runtime
total_runtime=0

# Read the log file line by line
while IFS= read -r line; do
    # Split the line into an array
    IFS=' ' read -r -a fields <<< "$line"
    
    # Extract the job id and the event type (start or end)
    job_id=${fields[0]}
    
    [[ "$job_id" == Scan ]] && echo $line && continue 
    
    [[ "$job_id" == nJobs ]] && nJobs=${fields[1]} && continue
    
    if [[ "$job_id" =~ ^-?[0-9]+$ ]]; then 

        event_type=${fields[1]}
        
        # Extract the time fields
        time_string="${fields[@]:3:6}"
        
        # Convert the time to seconds since the epoch
        event_time=$(date -d "$time_string" +%s)
        
        if [ "$event_type" == "start" ]; then
            # Store the start time in the associative array
            start_times[$job_id]=$event_time
        elif [ "$event_type" == "end" ]; then
            # Calculate the runtime and add it to the total_runtime
            start_time=${start_times[$job_id]}
            if [ -n "$start_time" ]; then
                runtime=$((event_time - start_time))
                job_runtimes[$job_id]=$runtime
                total_runtime=$((total_runtime + runtime))
            else 
                echo start missing start for $job_id
            fi
        fi
    else 
        continue
    fi
done < $1-log/runTime.txt 

RED='\033[0;31m'
NC='\033[0m' # No Color

count=0
# Print the runtime for each job in minutes
for job_id in `seq 1 $nJobs`; do
    runtime_seconds=${job_runtimes[$job_id]}
    if [ ! -n "$runtime_seconds" ]; then 
        echo -e "\n${RED}no data for job $job_id Here is the data for ${job_id}: ${NC}"
        grep "^$job_id " $1-log/runTime.txt 
        continue 
    fi 
    runtime_minutes=$((runtime_seconds / 60))
    echo "Job $job_id runtime: $runtime_minutes minutes or ($runtime_seconds seconds)"
    count=$((count+1))
done

[ $count -eq $nJobs ] && echo All jobs done

# Convert total runtime to minutes and print it
total_runtime_minutes=$((total_runtime / 60 / count))
echo "Total runtime: $total_runtime_minutes minutes or ($((total_runtime/count)) seconds)"
