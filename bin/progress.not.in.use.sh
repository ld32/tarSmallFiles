for folder in `find /n/data3_vast/data3_datasets/ld32/ /n/data3_vast/groups_datasets/ld32/ -mindepth 1 -maxdepth 1 -type d`; do 
    
    #[ -d $folder ] && continue

    [[ "$folder" == *Log ]] && continue 

    echo working on $folder

    folder_mtime=$(stat -c %Y "${folder}Log")
    current_time=$(date +%s)
    time_diff=$((current_time - folder_mtime))

    # 86400 seconds = 24 hours
    if [ $time_diff -gt 86400 ]; then
        echo "The folder $folder is more one day old."
    else
        echo "The folder $folder is less than one day old."
        du -s $folder >> progress.txt 
    fi
done

declare -A sizes

# Read the log file line by line
while IFS= read -r line; do
    # Split the line into an array
    IFS=' ' read -r -a fields <<< "$line"
    
    # Extract the job id and the event type (start or end)
    size=${fields[0]}
    name=${fields[1]}
        
    if [[ "$size" =~ ^-?[0-9]+$ ]]; then 
        sizes[name]=$size 
    fi 
done < progress.txt

totalSize=0

# Loop through the array and sum the sizes
for folder in "${!sizes[@]}"; do
  size=${sizes[$folder]}
  totalSize=$((totalSize + size))
done

# Print the total size
echo "Total size: $totalSize"