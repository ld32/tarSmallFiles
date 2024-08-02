# tar Small Files
To decrease number of small file, keep the folder structure, tar all files less than 1G

git clone https://github.com/ld32/tarSmallFiles.git

export PATH=$PWD/tarSmallFiles/bin:$PATH

## To tar:

### Single node job
Usage: sbatch -p short -t 12:0:0 --mem 20G --mail-type=all -c 20 --wrap="tar.sh \<nJobs\> \<sourceFolder\> \<destinationFolder\> singleNode

### Job array of 20 jobs
sbatch -p short -t 4:0:0 --mem 4G --mail-type=all -c 1 --wrap="tar.sh \<nJobs\> \<sourceFolder\> \<destinationFolder\> sbatch


### Exclsusive 20 jobs, meaning only one job run a certain node at the same time
sbatch -p short -t 4:0:0 --mem 4G --mail-type=all -c 1 --wrap="tar.sh 20 \<sourceFolder\> \<destinationFolder\> esbatch


## To untar:
Usage: untar.sh \<cores\> \<sourceFolder\> <destinationFolder>

For example:

untar.sh 4 /source/dir/to/data /destination/dir/to/data





