#!/bin/bash
# SEND SIDE FOLDER CRAWLER PROTOTYPE

echo "Starting folder packaging process..."

SOURCE_FOLDER="$1"
DATAFLOW_NAME="$2"
STAGING_DIR="$3"
WORK_DIR="$4"

# Default values if optional arguments are not provided
if [ -z "$DATAFLOW_NAME" ]; then
    DATAFLOW_NAME="foldercrawler"
fi

if [ -z "$STAGING_DIR" ]; then
    STAGING_DIR="/home/fastback/foldercrawler/staging"
fi

if [ -z "$WORK_DIR" ]; then
    WORK_DIR="/home/fastback/foldercrawler/tmp"
fi

# Whitelist and blacklist rules
WHITELIST_EXTENSIONS=("txt" "csv" "pdf")
BLACKLIST_EXTENSIONS=("log" "tmp")

# Check whether an extension exists in a provided list
extension_in_list() {
    local EXTENSION="$1"
    shift

    for ITEM in "$@"; do
        if [ "$EXTENSION" = "$ITEM" ]; then
            return 0
        fi
    done

    return 1
}

# Validate source folder argument
if [ -z "$SOURCE_FOLDER" ]; then
    echo "Error: No source folder provided."
    echo "Usage: ./package_folder.sh /path/to/source_folder dataflow_name /path/to/staging_folder /path/to/work_folder"
    exit 1
fi

# Validate that source folder exists
if [ ! -d "$SOURCE_FOLDER" ]; then
    echo "Error: Source folder '$SOURCE_FOLDER' does not exist."
    exit 1
fi

# Prevent work and staging directories from being the same
if [ "$STAGING_DIR" = "$WORK_DIR" ]; then
    echo "Error: Staging directory and work directory must be different."
    exit 1
fi

# Create required directories if they do not exist
mkdir -p "$STAGING_DIR"
mkdir -p "$WORK_DIR"

if [ $? -ne 0 ]; then
    echo "Error: Failed to create staging or work directory."
    exit 1
fi

# Generate unique package identifier
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
SHORT_ID=$(head /dev/urandom | tr -dc a-f0-9 | head -c 6)

PACKAGE_BASE="pkg_${TIMESTAMP}_${SHORT_ID}"

# Files are created in WORK_DIR first
PACKAGE_NAME="$WORK_DIR/${PACKAGE_BASE}.tar.gz"
HASH_FILE="$WORK_DIR/${PACKAGE_BASE}.sha256"
MANIFEST_FILE="$WORK_DIR/${PACKAGE_BASE}_manifest.txt"
INCLUDED_FILES_FILE="$WORK_DIR/${PACKAGE_BASE}_included_files.txt"
SKIPPED_FILES_FILE="$WORK_DIR/${PACKAGE_BASE}_skipped_files.txt"
READY_FILE="$WORK_DIR/${PACKAGE_BASE}.ready"

# Used to preserve the source folder name and its internal structure
SOURCE_PARENT=$(dirname "$SOURCE_FOLDER")

echo "Source folder: $SOURCE_FOLDER"
echo "Dataflow name: $DATAFLOW_NAME"
echo "Work directory: $WORK_DIR"
echo "Staging directory: $STAGING_DIR"
echo "Crawling source folder..."

FILE_COUNT=$(find "$SOURCE_FOLDER" -type f | wc -l)
FOLDER_COUNT=$(find "$SOURCE_FOLDER" -type d | wc -l)

echo "Files found: $FILE_COUNT"
echo "Folders found: $FOLDER_COUNT"

echo "Applying whitelist/blacklist rules..."

# Create or clear file lists
> "$INCLUDED_FILES_FILE"
> "$SKIPPED_FILES_FILE"

while IFS= read -r FILE; do
    FILE_NAME=$(basename "$FILE")

    if [[ "$FILE_NAME" == *.* ]]; then
        EXTENSION="${FILE_NAME##*.}"
    else
        EXTENSION=""
    fi

    EXTENSION=$(echo "$EXTENSION" | tr '[:upper:]' '[:lower:]')

    # Store a relative path so the archive does not contain /home/fastback/...
    RELATIVE_PATH="${FILE#"$SOURCE_PARENT"/}"

    if extension_in_list "$EXTENSION" "${BLACKLIST_EXTENSIONS[@]}"; then
        echo "$RELATIVE_PATH | skipped: blacklisted extension .$EXTENSION" >> "$SKIPPED_FILES_FILE"
        continue
    fi

    if ! extension_in_list "$EXTENSION" "${WHITELIST_EXTENSIONS[@]}"; then
        echo "$RELATIVE_PATH | skipped: not in whitelist .$EXTENSION" >> "$SKIPPED_FILES_FILE"
        continue
    fi

    echo "$RELATIVE_PATH" >> "$INCLUDED_FILES_FILE"
done < <(find "$SOURCE_FOLDER" -type f)

INCLUDED_COUNT=$(wc -l < "$INCLUDED_FILES_FILE")
SKIPPED_COUNT=$(wc -l < "$SKIPPED_FILES_FILE")

echo "Included files: $INCLUDED_COUNT"
echo "Skipped files: $SKIPPED_COUNT"
echo "Included files list created: $INCLUDED_FILES_FILE"
echo "Skipped files list created: $SKIPPED_FILES_FILE"

echo "File type summary:"

find "$SOURCE_FOLDER" -type f | while IFS= read -r FILE; do
    FILE_NAME=$(basename "$FILE")

    if [[ "$FILE_NAME" == *.* ]]; then
        EXTENSION="${FILE_NAME##*.}"
    else
        EXTENSION="no_extension"
    fi

    echo "$EXTENSION" | tr '[:upper:]' '[:lower:]'
done | sort | uniq -c

# Do not create an empty package
if [ "$INCLUDED_COUNT" -eq 0 ]; then
    echo "Error: No files matched the whitelist/blacklist rules."
    exit 1
fi

echo "Creating manifest..."

cat > "$MANIFEST_FILE" << EOF
package_id=$PACKAGE_BASE
package_name=$(basename "$PACKAGE_NAME")
source_folder=$SOURCE_FOLDER
dataflow_name=$DATAFLOW_NAME
created_at=$TIMESTAMP
file_count=$FILE_COUNT
folder_count=$FOLDER_COUNT
included_count=$INCLUDED_COUNT
skipped_count=$SKIPPED_COUNT
whitelist_extensions=${WHITELIST_EXTENSIONS[*]}
blacklist_extensions=${BLACKLIST_EXTENSIONS[*]}
hash_file=$(basename "$HASH_FILE")
included_files=$(basename "$INCLUDED_FILES_FILE")
skipped_files=$(basename "$SKIPPED_FILES_FILE")
ready_file=$(basename "$READY_FILE")
created_by=package_folder.sh
signature_enabled=false
signature_algorithm=TBD
signature_value=TBD
EOF

if [ $? -ne 0 ]; then
    echo "Error: Failed to create manifest."
    exit 1
fi

echo "Manifest created successfully: $MANIFEST_FILE"

echo "Creating tar.gz package..."

tar -czf "$PACKAGE_NAME" -C "$SOURCE_PARENT" -T "$INCLUDED_FILES_FILE"

if [ $? -ne 0 ]; then
    echo "Error: Failed to create package."
    exit 1
fi

echo "Package created successfully: $PACKAGE_NAME"

echo "Generating SHA256 hash..."

(
    cd "$WORK_DIR" || exit 1
    sha256sum "$(basename "$PACKAGE_NAME")" > "$(basename "$HASH_FILE")"
)

if [ $? -ne 0 ]; then
    echo "Error: Failed to generate hash."
    exit 1
fi

echo "SHA256 hash generated successfully: $HASH_FILE"

echo "Creating ready marker..."

cat > "$READY_FILE" << EOF
package_id=$PACKAGE_BASE
dataflow_name=$DATAFLOW_NAME
created_at=$TIMESTAMP
EOF

if [ $? -ne 0 ]; then
    echo "Error: Failed to create ready marker."
    exit 1
fi

echo "Moving completed package set to staging directory..."

# Move all package files first
mv \
    "$PACKAGE_NAME" \
    "$HASH_FILE" \
    "$MANIFEST_FILE" \
    "$INCLUDED_FILES_FILE" \
    "$SKIPPED_FILES_FILE" \
    "$STAGING_DIR/"

if [ $? -ne 0 ]; then
    echo "Error: Failed to move package files to staging directory."
    exit 1
fi

# Move ready marker last so the receiver knows the package set is complete
mv "$READY_FILE" "$STAGING_DIR/"

if [ $? -ne 0 ]; then
    echo "Error: Failed to move ready marker to staging directory."
    exit 1
fi

echo "Package set moved successfully to: $STAGING_DIR"
echo "Folder packaging process completed."