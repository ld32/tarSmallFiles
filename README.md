# tar Small Files
To decrease number of small file, keep the folder structure, tar all files in the same folder to a .tar file.

git clone https://github.com/ld32/tarSmallFiles.git

export PATH=$PWD/tarSmallFiles/bin:$PATH

## To run tar.sh:
sbatch -p short -t 4:0:0 -o slurm.esbatch.log -J eSbatch --mem 4G --mail-type=all -c 1 --wrap="tar.sh \<sourceFolder\> <nJobs> <esbatch>" 

For example:

sbatch -p short -t 4:0:0 -J eSbatch --mem 4G --mail-type=all -c 1 --wrap="tar.sh /n/scratch/users/l/ld32/datasets/dorsalhorn_th/intersection/catmaided/1TRaw/small 4 esbatch" -o destinationDir.log

## To check slurm short partition satuts, so that we have some jobs running, and pending or need submit more
checkQueue 

## To check jobs which are submitted for the folder:  
checkJobs \<destinationFolder\>

## To summarize run: 
summarizeRun \<destinationFolder\>

## To re-run failed jobs:
sbatch -p short -t 4:0:0 -J eSbatch --mem 4G --mail-type=all -c 1 --wrap="tar.sh \<sourceFolder\> <nJobs> <esbatch>" -o destinationDir.log

## Procedure to process the folders:

### 1 Before submitting/re-submitting, check how many jobs are running and pending. Make sure don't submit too many jobs.
checkQueue 

### 2 If there are some jobs running, but not sure which folders they are working on (Folder is copied from worksheet):
checkJobs \<destinationFolder\>

### 3 Check if the jobs indeed done for the folder (Folder is copied from worksheet):
summarizeRun \<destinationFolder\>

### 4 If there is no jobs running on the folder, and the folder is not finish yet, submit or re-submit with (Command is copied from worksheet): 
sbatch -p short -t 4:0:0 -J eSbatch --mem 4G --mail-type=all -c 1 --wrap="tar.sh \<sourceFolder\> <nJobs> <esbatch>" -o destinationDir.log

## Note: Folder level for the single process to scan is automatically chosen now


