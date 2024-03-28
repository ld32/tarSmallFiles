# tar Small Files
To decrease number of small file, keep the folder structure, tar all files less than 1G

git clone https://github.com/ld32/tarSmallFiles.git

export PATH=$PWD/tarSmallFiles/bin:$PATH

## To tar:
Usage: tar.sh \<cores\> \<sourceFolder\> [destinationFolder]

For example:

tar.sh 4 /source/dir/to/data /destination/dir/to/data

## To untar:
Usage: untar.sh \<cores\> \<sourceFolder\> [destinationFolder]

For example:

untar.sh 4 /source/dir/to/data /destination/dir/to/data




