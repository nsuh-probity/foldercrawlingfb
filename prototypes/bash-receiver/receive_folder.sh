#!/bin/bash
# RECEIVE SIDE FOLDER CRAWLER PROTOTYPE

echo "Starting receive-side folder processing..."

INCOMING_DIR="${1:-test_incoming}"
EXTRACTED_DIR="${2:-test_extracted}"
PROCESSED_DIR="${3:-test_processed}"
FAILED_DIR="${4:-test_failed}"

mkdir -p "$INCOMING_DIR"
mkdir -p "$EXTRACTED_DIR"
mkdir -p "$PROCESSED_DIR"
mkdir -p "$FAILED_DIR"

move_package_set() {
    local PACKAGE_BASE="$1"
    local DESTINATION_DIR="$2"

    for FILE in "$INCOMING_DIR/${PACKAGE_BASE}"*; do
        if [ -e "$FILE" ]; then
            mv "$FILE" "$DESTINATION_DIR/"
        fi
    done
}

FOUND_READY_FILE=false

for READY_FILE in "$INCOMING_DIR"/*.ready; do
    if [ ! -e "$READY_FILE" ]; then
        continue
    fi

    FOUND_READY_FILE=true

    READY_BASENAME=$(basename "$READY_FILE")
    PACKAGE_BASE="${READY_BASENAME%.ready}"

    PACKAGE_FILE="$INCOMING_DIR/${PACKAGE_BASE}.tar.gz"
    HASH_FILE="$INCOMING_DIR/${PACKAGE_BASE}.sha256"
    MANIFEST_FILE="$INCOMING_DIR/${PACKAGE_BASE}_manifest.txt"
    INCLUDED_FILES_FILE="$INCOMING_DIR/${PACKAGE_BASE}_included_files.txt"
    SKIPPED_FILES_FILE="$INCOMING_DIR/${PACKAGE_BASE}_skipped_files.txt"
    DESTINATION_DIR="$EXTRACTED_DIR/$PACKAGE_BASE"

    echo "Found completed package set: $PACKAGE_BASE"

    if [ ! -f "$PACKAGE_FILE" ]; then
        echo "Error: Missing package file: $PACKAGE_FILE"
        move_package_set "$PACKAGE_BASE" "$FAILED_DIR"
        continue
    fi

    if [ ! -f "$HASH_FILE" ]; then
        echo "Error: Missing hash file: $HASH_FILE"
        move_package_set "$PACKAGE_BASE" "$FAILED_DIR"
        continue
    fi

    if [ ! -f "$MANIFEST_FILE" ]; then
        echo "Error: Missing manifest file: $MANIFEST_FILE"
        move_package_set "$PACKAGE_BASE" "$FAILED_DIR"
        continue
    fi

    if [ ! -f "$INCLUDED_FILES_FILE" ]; then
        echo "Error: Missing included files list: $INCLUDED_FILES_FILE"
        move_package_set "$PACKAGE_BASE" "$FAILED_DIR"
        continue
    fi

    if [ ! -f "$SKIPPED_FILES_FILE" ]; then
        echo "Error: Missing skipped files list: $SKIPPED_FILES_FILE"
        move_package_set "$PACKAGE_BASE" "$FAILED_DIR"
        continue
    fi

    echo "Verifying SHA-256 hash..."

    (
        cd "$INCOMING_DIR" || exit 1
        sha256sum -c "$(basename "$HASH_FILE")"
    )

    if [ $? -ne 0 ]; then
        echo "Error: SHA-256 verification failed. Package will not be extracted."
        move_package_set "$PACKAGE_BASE" "$FAILED_DIR"
        continue
    fi

    echo "SHA-256 verification passed."

    echo "Checking archive for unsafe paths..."

    ARCHIVE_CONTENTS=$(tar -tzf "$PACKAGE_FILE")

    if [ $? -ne 0 ]; then
        echo "Error: Package archive could not be read."
        move_package_set "$PACKAGE_BASE" "$FAILED_DIR"
        continue
    fi

    if echo "$ARCHIVE_CONTENTS" | grep -E '(^/|(^|/)\.\.(/|$))' > /dev/null; then
        echo "Error: Archive contains unsafe paths."
        move_package_set "$PACKAGE_BASE" "$FAILED_DIR"
        continue
    fi

    mkdir -p "$DESTINATION_DIR"

    echo "Extracting package to: $DESTINATION_DIR"

    tar -xzf "$PACKAGE_FILE" -C "$DESTINATION_DIR"

    if [ $? -ne 0 ]; then
        echo "Error: Package extraction failed."
        move_package_set "$PACKAGE_BASE" "$FAILED_DIR"
        continue
    fi

    echo "Package extracted successfully."

    move_package_set "$PACKAGE_BASE" "$PROCESSED_DIR"

    echo "Package set moved to processed directory."
done

if [ "$FOUND_READY_FILE" = false ]; then
    echo "No completed package sets were found."
fi

echo "Receive-side folder processing completed."
