
#set -x 
# for each source folder


dDir=$1; 

[ -d ${dDir}Log ] || { echo "Usage: $0 <destinationDir>"; exit 1; } 

# get permission issue folder

declare -A findFolders # permission folders when runing find
declare -A cdFolders.  # cd folders when running cd

tempFile=$(mktemp)

echo > $dDir.path 
cat ${dDir}Log/scanError* | while IFS= read -r line; do
    #echo $line
    if [[ "$line" == find* ]]; then 
         echo find it  
         path=${line#*‘}; path=${path%’*}
         echo $path >> $tempFile
         #findFolders[$path] 
    fi 
done 

mv $tempFile $dDir.path  
wc -l $dDir.path  

# echo > $dDir.path1 
# cat $dDir.path | while IFS= read -r line; do
#     #echo $line
#     if [[ "$line" == find* ]]; then 
#          echo find it  
#          path=${line#*‘}; path=${path%’*}
#          echo $path >> $dDir.path1 
#          cdFolders[$path] 
#     fi 
# done 


# get_sorted_keys() {
#     local -n array=$1
#     for key in "${!array[@]}"; do
#         echo "$key"
#     done | sort
# }

# sorted_start_keys=$(get_sorted_keys start_times)
# sorted_end_keys=$(get_sorted_keys end_times)


# cat $dDir.path 


# echo "Do you want to chagne pemrisisn for these folders (y)"? 
# read -p "" x </dev/tty 

if [[ "$x" == y ]]; then 
    while true; do
        sudo -v
        sleep 300  # Refresh every 5 minutes
    done &
    cat $dDir.path  | while IFS= read -r folder; do
        #find $line -type d -exec chmod o+x {} \;
        sudo find "$folder" -type d -exec chmod o+x {} \; -print | tee -a "$output_file"
        sudo find . -type f -exec chmod o+r {} \;
    done
fi 


    
