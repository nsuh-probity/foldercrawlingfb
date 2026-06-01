#!/bin/bash
#SEND SIDE SIM
echo "Starting folder packaging process..."

SOURCE_FOLDER="$1"


DATAFLOW_NAME="$2"

if [ -z "$DATAFLOW_NAME" ]; then
    DATAFLOW_NAME="Folder_Package_Transfer"
fi




# varible for the folder that is going to be packaged ^
OUTPUT_DIR="output"


TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
SHORT_ID=$(head /dev/urandom | tr -dc a-f0-9 | head -c 6)

PACKAGE_BASE="pkg_${TIMESTAMP}_${SHORT_ID}"
PACKAGE_NAME="$OUTPUT_DIR/${PACKAGE_BASE}.tar.gz"
HASH_FILE="$OUTPUT_DIR/${PACKAGE_BASE}.sha256"
MANIFEST_FILE="$OUTPUT_DIR/${PACKAGE_BASE}_manifest.txt"
INCLUDED_FILES_FILE="$OUTPUT_DIR/${PACKAGE_BASE}_included_files.txt"


if [ -z "$SOURCE_FOLDER" ]; then
    echo "Error: No source folder provided."
    echo "Usage: ./package_folder.sh /path/to/folder"
    exit 1
fi


if [ ! -d "$SOURCE_FOLDER" ]; then
    echo "Error: Source folder '$SOURCE_FOLDER' does not exist."
    exit 1
fi

mkdir -p "$OUTPUT_DIR" #this means to create the output directory if it doesn't exist


echo "Folder Entered: $SOURCE_FOLDER"
echo "Crawling source folder..."

FILE_COUNT=$(find "$SOURCE_FOLDER" -type f | wc -l)
FOLDER_COUNT=$(find "$SOURCE_FOLDER" -type d | wc -l)


echo "Files found: $FILE_COUNT"
echo "Folders found: $FOLDER_COUNT"

echo "Writing included files list..."
find "$SOURCE_FOLDER" -type f > "$INCLUDED_FILES_FILE"
echo "Included files list created: $INCLUDED_FILES_FILE"


echo "File type summary:"
find "$SOURCE_FOLDER" -type f | while read -r FILE; do
    EXTENSION="${FILE##*.}"
    echo "$EXTENSION"
done | sort | uniq -c

echo "Creating manifest..."

cat > "$MANIFEST_FILE" << EOF
package_id=$PACKAGE_BASE
package_name=$(basename "$PACKAGE_NAME")
source_folder=$SOURCE_FOLDER
dataflow_name=$DATAFLOW_NAME
created_at=$TIMESTAMP
file_count=$FILE_COUNT
folder_count=$FOLDER_COUNT
hash_file=$(basename "$HASH_FILE")
included_files=$(basename "$INCLUDED_FILES_FILE")
created_by=package_folder.sh
signature_enabled=false
signature_algorithm=TBD
signature_value=TBD
EOF

echo "Manifest created successfully: $MANIFEST_FILE"




echo "Creating tar.gz package..."
tar -czf "$PACKAGE_NAME" "$SOURCE_FOLDER" 

if [ $? -ne 0 ]; then #this means if the last command failed, then do the following which is to print the error message and exit with a status code of 1 
    echo "Error: Failed to create package."
    exit 1
fi

echo "Package created successfully: $PACKAGE_NAME"

echo "Generating SHA256 hash..."
(
    cd "$OUTPUT_DIR" || exit 1
    sha256sum "$(basename "$PACKAGE_NAME")" > "$(basename "$HASH_FILE")"
) #this means to change the directory to the output directory and then generate the SHA256 hash of the package and save it to the hash file. The basename command is used to get the filename without the path.

if [ $? -ne 0 ]; then
    echo "Error: Failed to generate hash."
    exit 1
fi


echo "SHA256 hash generated successfully: $HASH_FILE"
echo "Folder packaging process completed."


