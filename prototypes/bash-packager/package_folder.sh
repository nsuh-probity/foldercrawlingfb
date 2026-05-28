#!/bin/bash
#SEND SIDE SIM
echo "Starting folder packaging process..."

BLACKLIST=()
WHITELIST=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --b) shift; while [[ $# -gt 0 && $1 != --* ]]; do BLACKLIST+=("$1"); shift; done ;;
        --w) shift; while [[ $# -gt 0 && $1 != --* ]]; do WHITELIST+=("$1"); shift; done ;;
        *) FOLDER="$1"; shift ;;
    esac
done

if [ -z "$FOLDER" ]; then
    echo "Usage: ./package_folder.sh /path/to/folder [--b ext1 ext2] [--w ext1 ext2]"
    exit 1
fi

FOLDER_NAME=$(basename "$FOLDER")
OUTPUT_DIR="output"
PACKAGE_NAME="$OUTPUT_DIR/${FOLDER_NAME}.tar.gz"
HASH_FILE="$OUTPUT_DIR/${FOLDER_NAME}_hash.sha256"

PY_ARGS=(python parsing.py --d "$FOLDER")
[[ ${#BLACKLIST[@]} -gt 0 ]] && PY_ARGS+=(--b "${BLACKLIST[@]}")
[[ ${#WHITELIST[@]} -gt 0 ]] && PY_ARGS+=(--w "${WHITELIST[@]}")

mapfile -t FILES < <("${PY_ARGS[@]}" | tr -d '\r')

if [ ${#FILES[@]} -eq 0 ]; then
    echo "Error: No files returned from parsing.py."
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

PREFIXED_FILES=()
for f in "${FILES[@]}"; do
    PREFIXED_FILES+=("$FOLDER_NAME/$f")
done

echo "Files to package: ${PREFIXED_FILES[*]}"

echo "Creating tar.gz package..."
tar -czf "$PACKAGE_NAME" -C "$(dirname "$FOLDER")" "${PREFIXED_FILES[@]}"

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
mkdir -p "$OUTPUT_DIR"


echo "SHA256 hash generated successfully: $HASH_FILE"
echo "Folder packaging process completed."


