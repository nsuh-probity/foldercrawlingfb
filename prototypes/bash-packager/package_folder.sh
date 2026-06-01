#!/bin/bash
# SEND SIDE SIM
# Packages a folder into a tar.gz archive with an optional file filter (blacklist/whitelist),
# then generates a SHA256 hash of the resulting archive.
echo "Starting folder packaging process..."

SOURCE_FOLDER="$1"
DATAFLOW_NAME="$2"
[[ $# -ge 2 ]] && shift 2 || shift $#

BLACKLIST=()
WHITELIST=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --b) shift; while [[ $# -gt 0 && $1 != --* ]]; do BLACKLIST+=("$1"); shift; done ;;
        --w) shift; while [[ $# -gt 0 && $1 != --* ]]; do WHITELIST+=("$1"); shift; done ;;
        *) shift ;;
    esac
done

if [ -z "$DATAFLOW_NAME" ]; then
    DATAFLOW_NAME="Folder_Package_Transfer"
fi

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
    echo "Usage: ./package_folder.sh /path/to/folder [dataflow_name] [--b ext1 ext2] [--w ext1 ext2]"
    exit 1
fi

if [ ! -d "$SOURCE_FOLDER" ]; then
    echo "Error: Source folder '$SOURCE_FOLDER' does not exist."
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "Folder Entered: $SOURCE_FOLDER"
echo "Crawling source folder..."

PY_ARGS=(python parsing.py --d "$SOURCE_FOLDER")
[[ ${#BLACKLIST[@]} -gt 0 ]] && PY_ARGS+=(--b "${BLACKLIST[@]}")
[[ ${#WHITELIST[@]} -gt 0 ]] && PY_ARGS+=(--w "${WHITELIST[@]}")

# Run parsing.py to get the filtered list of relative file paths; strip Windows \r line endings
mapfile -t FILES < <("${PY_ARGS[@]}" | tr -d '\r')

if [ ${#FILES[@]} -eq 0 ]; then
    echo "Error: No files returned from parsing.py."
    exit 1
fi

FILE_COUNT=${#FILES[@]}
FOLDER_COUNT=$(find "$SOURCE_FOLDER" -type d | wc -l)

echo "Files found: $FILE_COUNT"
echo "Folders found: $FOLDER_COUNT"

echo "Writing included files list..."
printf '%s\n' "${FILES[@]}" > "$INCLUDED_FILES_FILE"
echo "Included files list created: $INCLUDED_FILES_FILE"

echo "File type summary:"
printf '%s\n' "${FILES[@]}" | while read -r FILE; do
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

FOLDER_NAME=$(basename "$SOURCE_FOLDER")
PREFIXED_FILES=()
for f in "${FILES[@]}"; do
    PREFIXED_FILES+=("$FOLDER_NAME/$f")
done

tar -czf "$PACKAGE_NAME" -C "$(dirname "$SOURCE_FOLDER")" "${PREFIXED_FILES[@]}"

if [ $? -ne 0 ]; then
    echo "Error: Failed to create package."
    exit 1
fi

echo "Package created successfully: $PACKAGE_NAME"

# Generate SHA256 hash; run in a subshell so sha256sum writes only the bare filename (not a full path) into the hash file
echo "Generating SHA256 hash..."
(
    cd "$OUTPUT_DIR" || exit 1
    sha256sum "$(basename "$PACKAGE_NAME")" > "$(basename "$HASH_FILE")"
)

if [ $? -ne 0 ]; then
    echo "Error: Failed to generate hash."
    exit 1
fi

echo "SHA256 hash generated successfully: $HASH_FILE"
echo "Folder packaging process completed."
