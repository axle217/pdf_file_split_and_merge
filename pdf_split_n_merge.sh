#!/usr/bin/env bash

# This file is named pdf_split_n_merge.sh, a script to split and merge pdf files.
# Example usage:
#         ./pdf_split_n_merge.sh output.pdf file1.pdf:1-3,5 file2.pdf:2,4
# Pages to be merged (entire file if not provided):   |___|           |_|

set -e

# ---- Helper: install poppler if missing ----
install_poppler() {
    echo "Poppler utilities not found. Installing..."

    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update && sudo apt-get install -y poppler-utils
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y poppler-utils
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y poppler-utils
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --noconfirm poppler
    elif command -v brew >/dev/null 2>&1; then
        brew install poppler
    else
        echo "Unsupported package manager. Please install poppler manually."
        exit 1
    fi
}

# ---- Check dependencies ----
if ! command -v pdfseparate >/dev/null 2>&1 || ! command -v pdfunite >/dev/null 2>&1; then
    install_poppler
fi

# ---- Usage ----
usage() {
    echo "Usage:"
    echo "$0 output.pdf input1.pdf:pages input2.pdf:pages ..."
    echo
    echo "Example:"
    echo "$0 result.pdf file1.pdf:1-3,5 file2.pdf:2,4-6"
    exit 1
}

[ "$#" -lt 2 ] && usage

OUTPUT="$1"
shift

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

EXTRACTED_FILES=()

# ---- Function to expand page ranges ----
expand_pages() {
    local input="$1"
    local pages="$2"

    IFS=',' read -ra PARTS <<< "$pages"

    for part in "${PARTS[@]}"; do
        if [[ "$part" == *-* ]]; then
            start=${part%-*}
            end=${part#*-}
            for ((i=start; i<=end; i++)); do
                echo "$i"
            done
        else
            echo "$part"
        fi
    done
}

# ---- Get total pages ----
get_total_pages() {
    local file="$1"
    pdfinfo "$file" | awk '/^Pages:/ {print $2}'
}

# ---- Process each input ----
for arg in "$@"; do
    if [[ "$arg" == *:* ]]; then
        FILE="${arg%%:*}"
        PAGES="${arg##*:}"
    else
        FILE="$arg"
        TOTAL=$(get_total_pages "$FILE")
        PAGES="1-$TOTAL"
    fi

    if [ ! -f "$FILE" ]; then
        echo "File not found: $FILE"
        exit 1
    fi

    if [[ "$PAGES" == "1-$TOTAL" ]]; then
        EXTRACTED_FILES+=("$FILE")
    else
        for page in $(expand_pages "$FILE" "$PAGES"); do
            OUTFILE="$TMP_DIR/$(basename "$FILE")_page_$page.pdf"
            pdfseparate -f "$page" -l "$page" "$FILE" "$OUTFILE"
            EXTRACTED_FILES+=("$OUTFILE")
        done
    fi
done

# ---- Merge ----
echo "Merging into $OUTPUT..."
pdfunite "${EXTRACTED_FILES[@]}" "$OUTPUT"

echo "Done: $OUTPUT"
