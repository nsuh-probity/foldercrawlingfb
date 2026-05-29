#!/bin/bash
# SEND SIDE SIM
# Packages a folder into a tar.gz archive with an optional file filter (blacklist/whitelist),
# then generates a SHA256 hash of the resulting archive.
echo "Starting folder packaging process..."

# Arrays to hold file extension filters passed in via --b and --w flags
BLACKLIST=()
WHITELIST=()

# Parse CLI arguments: positional arg sets FOLDER, --b collects blacklist extensions, --w collects whitelist extensions
while [[ $# -gt 0 ]]; do
    case $1 in
        --b) shift; while [[ $# -gt 0 && $1 != --* ]]; do BLACKLIST+=("$1"); shift; done ;;
        --w) shift; while [[ $# -gt 0 && $1 != --* ]]; do WHITELIST+=("$1"); shift; done ;;
        *) FOLDER="$1"; shift ;;
    esac
done

# Require a folder path; print usage and exit if missing
if [ -z "$FOLDER" ]; then
    echo "Usage: ./package_folder.sh /path/to/folder [--b ext1 ext2] [--w ext1 ext2]"
    exit 1
fi

# Derive output file names from the folder's base name
FOLDER_NAME=$(basename "$FOLDER")
OUTPUT_DIR="output"
PACKAGE_NAME="$OUTPUT_DIR/${FOLDER_NAME}.tar.gz"
HASH_FILE="$OUTPUT_DIR/${FOLDER_NAME}_hash.sha256"

# Build the argument list for parsing.py, appending filter flags only when provided
PY_ARGS=(python parsing.py --d "$FOLDER")
[[ ${#BLACKLIST[@]} -gt 0 ]] && PY_ARGS+=(--b "${BLACKLIST[@]}")
[[ ${#WHITELIST[@]} -gt 0 ]] && PY_ARGS+=(--w "${WHITELIST[@]}")

# Run parsing.py to get the filtered list of relative file paths; strip Windows \r line endings
mapfile -t FILES < <("${PY_ARGS[@]}" | tr -d '\r')

# Abort if parsing.py returned no files (nothing to package)
if [ ${#FILES[@]} -eq 0 ]; then
    echo "Error: No files returned from parsing.py."
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Prefix each relative path with the folder name so tar preserves the top-level directory inside the archive
PREFIXED_FILES=()
for f in "${FILES[@]}"; do
    PREFIXED_FILES+=("$FOLDER_NAME/$f")
done

echo "Files to package: ${PREFIXED_FILES[*]}"

# Create the compressed archive; -C sets the working directory so paths inside the archive are relative
echo "Creating tar.gz package..."
tar -czf "$PACKAGE_NAME" -C "$(dirname "$FOLDER")" "${PREFIXED_FILES[@]}"

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
