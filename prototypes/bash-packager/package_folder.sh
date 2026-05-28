#!/bin/bash
#SEND SIDE SIM
echo "Starting folder packaging process..."

SOURCE_FOLDER="$1"
# varible for the folder that is going to be packaged ^
OUTPUT_DIR="output"
PACKAGE_NAME="$OUTPUT_DIR/folder_package.tar.gz"
HASH_FILE="$OUTPUT_DIR/folder_package_hash.sha256"


if [ -z "$SOURCE_FOLDER" ]; then
    echo "Error: No source folder provided."
    echo "Usage: ./package_folder.sh /path/to/folder"
    exit 1
fi


if [ ! -d "$SOURCE_FOLDER" ]; then
    echo "Error: Source folder '$SOURCE_FOLDER' does not exist."
    exit 1
fi




echo "Folder Entered: $SOURCE_FOLDER"

echo "Creating tar.gz package..."
tar -czf "$PACKAGE_NAME" "$SOURCE_FOLDER" 

if [ $? -ne 0 ]; then #this means if the last command failed, then do the following which is to print the error message and exit with a status code of 1 
    echo "Error: Failed to create package."
    exit 1
fi

echo "Package created successfully: $PACKAGE_NAME"

echo "Generating SHA256 hash..."
sha256sum "$PACKAGE_NAME" > "$HASH_FILE" #this means to generate the hash of the package and save it to a file called folder_package_hash.sha256

if [ $? -ne 0 ]; then
    echo "Error: Failed to generate hash."
    exit 1
fi
mkdir -p "$OUTPUT_DIR"


echo "SHA256 hash generated successfully: $HASH_FILE"
echo "Folder packaging process completed."


