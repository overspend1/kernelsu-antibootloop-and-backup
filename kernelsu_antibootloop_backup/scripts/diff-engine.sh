#!/system/bin/sh
# KernelSU Anti-Bootloop Backup Differential Engine
# Handles binary diffing, compression, and deduplication

MODDIR=${0%/*}
MODDIR=${MODDIR%/*}
CONFIG_DIR="$MODDIR/config"
DIFF_DIR="$CONFIG_DIR/diffs"
HASH_DIR="$CONFIG_DIR/hashes"

# Ensure directories exist
mkdir -p "$DIFF_DIR"
mkdir -p "$HASH_DIR"

# Log function
log_message() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$CONFIG_DIR/diff_engine.log"
}

log_message "Differential engine started"

# -----------------------------------------------
# BLOCK DIFFERENCE ANALYZER
# -----------------------------------------------

# Calculate differences between two files at block level
calculate_binary_diff() {
    SOURCE="$1"
    TARGET="$2"
    OUTPUT="$3"
    BLOCK_SIZE="$4"
    
    # Default block size is 4KB if not specified
    if [ -z "$BLOCK_SIZE" ]; then
        BLOCK_SIZE=4096
    fi
    
    log_message "Calculating binary diff between $SOURCE and $TARGET with block size $BLOCK_SIZE"
    
    if [ ! -f "$SOURCE" ] || [ ! -f "$TARGET" ]; then
        log_message "Error: Source or target file does not exist"
        return 1
    fi
    
    # Create temporary directory for diff processing
    TEMP_DIR="$DIFF_DIR/temp_$(date +%s%N)"
    mkdir -p "$TEMP_DIR"
    
    # Get file sizes
    SOURCE_SIZE=$(stat -c %s "$SOURCE" 2>/dev/null)
    TARGET_SIZE=$(stat -c %s "$TARGET" 2>/dev/null)
    
    if [ -z "$SOURCE_SIZE" ] || [ -z "$TARGET_SIZE" ]; then
        log_message "Error: Failed to get file sizes"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    # Calculate total blocks
    SOURCE_BLOCKS=$((SOURCE_SIZE / BLOCK_SIZE))
    if [ $((SOURCE_SIZE % BLOCK_SIZE)) -ne 0 ]; then
        SOURCE_BLOCKS=$((SOURCE_BLOCKS + 1))
    fi
    
    TARGET_BLOCKS=$((TARGET_SIZE / BLOCK_SIZE))
    if [ $((TARGET_SIZE % BLOCK_SIZE)) -ne 0 ]; then
        TARGET_BLOCKS=$((TARGET_BLOCKS + 1))
    fi
    
    log_message "Source has $SOURCE_BLOCKS blocks, Target has $TARGET_BLOCKS blocks"
    
    # Create diff metadata
    cat > "$TEMP_DIR/diff_metadata" << EOF
SOURCE_SIZE=$SOURCE_SIZE
TARGET_SIZE=$TARGET_SIZE
BLOCK_SIZE=$BLOCK_SIZE
SOURCE_BLOCKS=$SOURCE_BLOCKS
TARGET_BLOCKS=$TARGET_BLOCKS
TIMESTAMP=$(date +%s)
EOF
    
    # Split source and target into blocks and compare
    DIFF_BLOCKS=0
    SAME_BLOCKS=0
    
    for ((i=0; i<SOURCE_BLOCKS && i<TARGET_BLOCKS; i++)); do
        OFFSET=$((i * BLOCK_SIZE))
        
        # Extract blocks
        dd if="$SOURCE" of="$TEMP_DIR/source_block.$i" bs="$BLOCK_SIZE" skip="$i" count=1 2>/dev/null
        dd if="$TARGET" of="$TEMP_DIR/target_block.$i" bs="$BLOCK_SIZE" skip="$i" count=1 2>/dev/null
        
        # Compare blocks
        if ! cmp -s "$TEMP_DIR/source_block.$i" "$TEMP_DIR/target_block.$i"; then
            # Blocks are different
            echo "$i:diff" >> "$TEMP_DIR/block_map"
            cp "$TEMP_DIR/target_block.$i" "$TEMP_DIR/diff_block.$i"
            DIFF_BLOCKS=$((DIFF_BLOCKS + 1))
        else
            # Blocks are the same
            echo "$i:same" >> "$TEMP_DIR/block_map"
            SAME_BLOCKS=$((SAME_BLOCKS + 1))
        fi
        
        # Clean up temporary block files
        rm -f "$TEMP_DIR/source_block.$i" "$TEMP_DIR/target_block.$i"
    done
    
    # Handle case where target has more blocks than source
    for ((i=SOURCE_BLOCKS; i<TARGET_BLOCKS; i++)); do
        OFFSET=$((i * BLOCK_SIZE))
        
        # Extract the additional block from target
        dd if="$TARGET" of="$TEMP_DIR/diff_block.$i" bs="$BLOCK_SIZE" skip="$i" count=1 2>/dev/null
        
        # Mark as new block
        echo "$i:new" >> "$TEMP_DIR/block_map"
        DIFF_BLOCKS=$((DIFF_BLOCKS + 1))
    done
    
    # Update metadata with block counts
    echo "DIFF_BLOCKS=$DIFF_BLOCKS" >> "$TEMP_DIR/diff_metadata"
    echo "SAME_BLOCKS=$SAME_BLOCKS" >> "$TEMP_DIR/block_map"
    
    # Package the diff
    tar -czf "$OUTPUT" -C "$TEMP_DIR" diff_metadata block_map diff_block.* 2>/dev/null
    
    # Clean up
    rm -rf "$TEMP_DIR"
    
    log_message "Binary diff completed: $DIFF_BLOCKS different blocks, $SAME_BLOCKS same blocks"
    return 0
}

# Apply a binary diff to restore the target file
apply_binary_diff() {
    SOURCE="$1"
    DIFF="$2"
    OUTPUT="$3"
    
    log_message "Applying binary diff from $DIFF to $SOURCE"
    
    if [ ! -f "$SOURCE" ] || [ ! -f "$DIFF" ]; then
        log_message "Error: Source or diff file does not exist"
        return 1
    fi
    
    # Create temporary directory for diff processing
    TEMP_DIR="$DIFF_DIR/temp_$(date +%s%N)"
    mkdir -p "$TEMP_DIR"
    
    # Extract diff package
    if ! tar -xzf "$DIFF" -C "$TEMP_DIR" 2>/dev/null; then
        log_message "Error: Failed to extract diff package"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    # Check if required files exist
    if [ ! -f "$TEMP_DIR/diff_metadata" ] || [ ! -f "$TEMP_DIR/block_map" ]; then
        log_message "Error: Diff package is missing required files"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    # Load metadata
    . "$TEMP_DIR/diff_metadata"
    
    # Create target file
    dd if=/dev/zero of="$OUTPUT" bs=1 count=0 seek="$TARGET_SIZE" 2>/dev/null
    
    # Apply block map
    while IFS=: read -r BLOCK_NUM BLOCK_TYPE; do
        if [ "$BLOCK_TYPE" = "same" ]; then
            # Copy block from source
            dd if="$SOURCE" of="$OUTPUT" bs="$BLOCK_SIZE" skip="$BLOCK_NUM" seek="$BLOCK_NUM" count=1 conv=notrunc 2>/dev/null
        elif [ "$BLOCK_TYPE" = "diff" ] || [ "$BLOCK_TYPE" = "new" ]; then
            # Copy block from diff
            if [ -f "$TEMP_DIR/diff_block.$BLOCK_NUM" ]; then
                dd if="$TEMP_DIR/diff_block.$BLOCK_NUM" of="$OUTPUT" bs="$BLOCK_SIZE" seek="$BLOCK_NUM" count=1 conv=notrunc 2>/dev/null
            else
                log_message "Warning: Missing diff block $BLOCK_NUM"
            fi
        fi
    done < "$TEMP_DIR/block_map"
    
    # Clean up
    rm -rf "$TEMP_DIR"
    
    log_message "Binary diff applied successfully"
    return 0
}

# -----------------------------------------------
# COMPRESSION SUBSYSTEM
# -----------------------------------------------

# Get available compression methods
get_compression_methods() {
    METHODS=""
    
    # Check for gzip
    if command -v gzip >/dev/null 2>&1; then
        METHODS="$METHODS gzip"
    fi
    
    # Check for bzip2
    if command -v bzip2 >/dev/null 2>&1; then
        METHODS="$METHODS bzip2"
    fi
    
    # Check for xz
    if command -v xz >/dev/null 2>&1; then
        METHODS="$METHODS xz"
    fi
    
    # Check for lz4
    if command -v lz4 >/dev/null 2>&1; then
        METHODS="$METHODS lz4"
    fi
    
    # Always include raw (no compression)
    METHODS="$METHODS raw"
    
    echo "$METHODS"
}

# Compress a file using specified method
compress_file() {
    INPUT="$1"
    OUTPUT="$2"
    METHOD="$3"
    LEVEL="$4"
    
    # Default to gzip if method not specified
    if [ -z "$METHOD" ]; then
        METHOD="gzip"
    fi
    
    # Default compression level if not specified
    if [ -z "$LEVEL" ]; then
        LEVEL="6"
    fi
    
    log_message "Compressing $INPUT using $METHOD level $LEVEL"
    
    if [ ! -f "$INPUT" ]; then
        log_message "Error: Input file does not exist"
        return 1
    fi
    
    case "$METHOD" in
        "gzip")
            if ! gzip -c -"$LEVEL" "$INPUT" > "$OUTPUT" 2>/dev/null; then
                log_message "Error: gzip compression failed"
                return 1
            fi
            ;;
        "bzip2")
            if ! bzip2 -c -"$LEVEL" "$INPUT" > "$OUTPUT" 2>/dev/null; then
                log_message "Error: bzip2 compression failed"
                return 1
            fi
            ;;
        "xz")
            if ! xz -c -"$LEVEL" "$INPUT" > "$OUTPUT" 2>/dev/null; then
                log_message "Error: xz compression failed"
                return 1
            fi
            ;;
        "lz4")
            if ! lz4 -c "$INPUT" > "$OUTPUT" 2>/dev/null; then
                log_message "Error: lz4 compression failed"
                return 1
            fi
            ;;
        "raw")
            if ! cp "$INPUT" "$OUTPUT" 2>/dev/null; then
                log_message "Error: copy failed"
                return 1
            fi
            ;;
        *)
            log_message "Error: Unknown compression method $METHOD"
            return 1
            ;;
    esac
    
    # Calculate compression ratio
    ORIGINAL_SIZE=$(stat -c %s "$INPUT" 2>/dev/null)
    COMPRESSED_SIZE=$(stat -c %s "$OUTPUT" 2>/dev/null)
    
    if [ -n "$ORIGINAL_SIZE" ] && [ -n "$COMPRESSED_SIZE" ] && [ "$ORIGINAL_SIZE" -gt 0 ]; then
        RATIO=$(( (ORIGINAL_SIZE - COMPRESSED_SIZE) * 100 / ORIGINAL_SIZE ))
        log_message "Compression ratio: $RATIO% (from $ORIGINAL_SIZE to $COMPRESSED_SIZE bytes)"
    fi
    
    return 0
}

# Decompress a file using specified method
decompress_file() {
    INPUT="$1"
    OUTPUT="$2"
    METHOD="$3"
    
    # Default to gzip if method not specified
    if [ -z "$METHOD" ]; then
        METHOD="gzip"
    fi
    
    log_message "Decompressing $INPUT using $METHOD"
    
    if [ ! -f "$INPUT" ]; then
        log_message "Error: Input file does not exist"
        return 1
    fi
    
    case "$METHOD" in
        "gzip")
            if ! gzip -d -c "$INPUT" > "$OUTPUT" 2>/dev/null; then
                log_message "Error: gzip decompression failed"
                return 1
            fi
            ;;
        "bzip2")
            if ! bzip2 -d -c "$INPUT" > "$OUTPUT" 2>/dev/null; then
                log_message "Error: bzip2 decompression failed"
                return 1
            fi
            ;;
        "xz")
            if ! xz -d -c "$INPUT" > "$OUTPUT" 2>/dev/null; then
                log_message "Error: xz decompression failed"
                return 1
            fi
            ;;
        "lz4")
            if ! lz4 -d -c "$INPUT" > "$OUTPUT" 2>/dev/null; then
                log_message "Error: lz4 decompression failed"
                return 1
            fi
            ;;
        "raw")
            if ! cp "$INPUT" "$OUTPUT" 2>/dev/null; then
                log_message "Error: copy failed"
                return 1
            fi
            ;;
        *)
            log_message "Error: Unknown compression method $METHOD"
            return 1
            ;;
    esac
    
    log_message "Decompression completed successfully"
    return 0
}

# Test and select best compression method for a file
select_best_compression() {
    INPUT="$1"
    OUTPUT_PREFIX="$2"
    
    log_message "Selecting best compression method for $INPUT"
    
    if [ ! -f "$INPUT" ]; then
        log_message "Error: Input file does not exist"
        return 1
    fi
    
    # Get original file size
    ORIGINAL_SIZE=$(stat -c %s "$INPUT" 2>/dev/null)
    if [ -z "$ORIGINAL_SIZE" ]; then
        log_message "Error: Failed to get original file size"
        return 1
    fi
    
    # Get available compression methods
    METHODS=$(get_compression_methods)
    
    # Test each method
    BEST_METHOD="raw"
    BEST_SIZE="$ORIGINAL_SIZE"
    BEST_OUTPUT=""
    
    for METHOD in $METHODS; do
        # Skip raw method in test
        if [ "$METHOD" = "raw" ]; then
            continue
        fi
        
        TEST_OUTPUT="${OUTPUT_PREFIX}.${METHOD}"
        
        # Compress with the method
        if compress_file "$INPUT" "$TEST_OUTPUT" "$METHOD" "6"; then
            # Get compressed size
            COMPRESSED_SIZE=$(stat -c %s "$TEST_OUTPUT" 2>/dev/null)
            
            if [ -n "$COMPRESSED_SIZE" ] && [ "$COMPRESSED_SIZE" -lt "$BEST_SIZE" ]; then
                # Found better compression
                if [ -n "$BEST_OUTPUT" ] && [ "$BEST_METHOD" != "raw" ]; then
                    rm -f "$BEST_OUTPUT"
                fi
                
                BEST_METHOD="$METHOD"
                BEST_SIZE="$COMPRESSED_SIZE"
                BEST_OUTPUT="$TEST_OUTPUT"
            else
                # Not better, remove test file
                rm -f "$TEST_OUTPUT"
            fi
        else
            # Compression failed, remove test file if exists
            rm -f "$TEST_OUTPUT" 2>/dev/null
        fi
    done
    
    # If best method is still raw, just copy the file
    if [ "$BEST_METHOD" = "raw" ]; then
        cp "$INPUT" "${OUTPUT_PREFIX}.raw" 2>/dev/null
        BEST_OUTPUT="${OUTPUT_PREFIX}.raw"
    fi
    
    # Create metadata file
    echo "METHOD=$BEST_METHOD" > "${OUTPUT_PREFIX}.meta"
    echo "ORIGINAL_SIZE=$ORIGINAL_SIZE" >> "${OUTPUT_PREFIX}.meta"
    echo "COMPRESSED_SIZE=$BEST_SIZE" >> "${OUTPUT_PREFIX}.meta"
    
    if [ "$ORIGINAL_SIZE" -gt 0 ]; then
        RATIO=$(( (ORIGINAL_SIZE - BEST_SIZE) * 100 / ORIGINAL_SIZE ))
        echo "RATIO=$RATIO" >> "${OUTPUT_PREFIX}.meta"
    fi
    
    log_message "Best compression method: $BEST_METHOD (ratio: $RATIO%)"
    
    # Return best method and output file
    echo "$BEST_METHOD:$BEST_OUTPUT"
    return 0
}

# -----------------------------------------------
# DEDUPLICATION ENGINE
# -----------------------------------------------

# Calculate SHA-256 hash of a file
calculate_hash() {
    FILE="$1"
    
    if [ ! -f "$FILE" ]; then
        log_message "Error: File does not exist for hashing"
        return 1
    fi
    
    # Use sha256sum if available, fall back to md5sum
    if command -v sha256sum >/dev/null 2>&1; then
        HASH=$(sha256sum "$FILE" | awk '{print $1}')
    else
        HASH=$(md5sum "$FILE" | awk '{print $1}')
    fi
    
    if [ -n "$HASH" ]; then
        echo "$HASH"
        return 0
    else
        log_message "Error: Failed to calculate hash for $FILE"
        return 1
    fi
}

# Calculate hash for each block in a file
calculate_block_hashes() {
    FILE="$1"
    OUTPUT="$2"
    BLOCK_SIZE="$3"
    
    # Default block size is 4MB if not specified
    if [ -z "$BLOCK_SIZE" ]; then
        BLOCK_SIZE=4194304  # 4MB
    fi
    
    log_message "Calculating block hashes for $FILE with block size $BLOCK_SIZE"
    
    if [ ! -f "$FILE" ]; then
        log_message "Error: File does not exist"
        return 1
    fi
    
    # Get file size
    FILE_SIZE=$(stat -c %s "$FILE" 2>/dev/null)
    if [ -z "$FILE_SIZE" ]; then
        log_message "Error: Failed to get file size"
        return 1
    fi
    
    # Calculate total blocks
    BLOCKS=$((FILE_SIZE / BLOCK_SIZE))
    if [ $((FILE_SIZE % BLOCK_SIZE)) -ne 0 ]; then
        BLOCKS=$((BLOCKS + 1))
    fi
    
    log_message "File has $BLOCKS blocks"
    
    # Create temporary directory
    TEMP_DIR="$HASH_DIR/temp_$(date +%s%N)"
    mkdir -p "$TEMP_DIR"
    
    # Process each block
    for ((i=0; i<BLOCKS; i++)); do
        OFFSET=$((i * BLOCK_SIZE))
        
        # Extract block
        dd if="$FILE" of="$TEMP_DIR/block.$i" bs="$BLOCK_SIZE" skip="$i" count=1 2>/dev/null
        
        # Calculate hash
        HASH=$(calculate_hash "$TEMP_DIR/block.$i")
        
        if [ -n "$HASH" ]; then
            echo "$i:$HASH" >> "$OUTPUT"
        else
            log_message "Warning: Failed to hash block $i"
            echo "$i:FAILED" >> "$OUTPUT"
        fi
        
        # Clean up block file
        rm -f "$TEMP_DIR/block.$i"
    done
    
    # Clean up
    rm -rf "$TEMP_DIR"
    
    log_message "Block hashing completed for $FILE ($BLOCKS blocks)"
    return 0
}

# Deduplicate a file against a reference
deduplicate_file() {
    SOURCE="$1"
    REFERENCE="$2"
    OUTPUT="$3"
    BLOCK_SIZE="$4"
    
    # Default block size is 4MB if not specified
    if [ -z "$BLOCK_SIZE" ]; then
        BLOCK_SIZE=4194304  # 4MB
    fi
    
    log_message "Deduplicating $SOURCE against $REFERENCE with block size $BLOCK_SIZE"
    
    if [ ! -f "$SOURCE" ] || [ ! -f "$REFERENCE" ]; then
        log_message "Error: Source or reference file does not exist"
        return 1
    fi
    
    # Create temporary directory
    TEMP_DIR="$HASH_DIR/temp_$(date +%s%N)"
    mkdir -p "$TEMP_DIR"
    
    # Calculate block hashes for source and reference
    calculate_block_hashes "$SOURCE" "$TEMP_DIR/source_hashes" "$BLOCK_SIZE"
    calculate_block_hashes "$REFERENCE" "$TEMP_DIR/reference_hashes" "$BLOCK_SIZE"
    
    # Get file sizes
    SOURCE_SIZE=$(stat -c %s "$SOURCE" 2>/dev/null)
    REFERENCE_SIZE=$(stat -c %s "$REFERENCE" 2>/dev/null)
    
    if [ -z "$SOURCE_SIZE" ] || [ -z "$REFERENCE_SIZE" ]; then
        log_message "Error: Failed to get file sizes"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    # Calculate total blocks
    SOURCE_BLOCKS=$((SOURCE_SIZE / BLOCK_SIZE))
    if [ $((SOURCE_SIZE % BLOCK_SIZE)) -ne 0 ]; then
        SOURCE_BLOCKS=$((SOURCE_BLOCKS + 1))
    fi
    
    # Create metadata
    cat > "$TEMP_DIR/metadata" << EOF
SOURCE_SIZE=$SOURCE_SIZE
REFERENCE_SIZE=$REFERENCE_SIZE
BLOCK_SIZE=$BLOCK_SIZE
SOURCE_BLOCKS=$SOURCE_BLOCKS
TIMESTAMP=$(date +%s)
EOF
    
    # Create block map and extract unique blocks
    UNIQUE_BLOCKS=0
    DEDUPLICATED_BLOCKS=0
    
    # Load reference hashes into memory
    declare -A REF_HASHES
    while IFS=: read -r REF_BLOCK REF_HASH; do
        REF_HASHES["$REF_HASH"]="$REF_BLOCK"
    done < "$TEMP_DIR/reference_hashes"
    
    # Process source blocks
    while IFS=: read -r SRC_BLOCK SRC_HASH; do
        if [ -n "${REF_HASHES[$SRC_HASH]}" ]; then
            # Block exists in reference
            echo "$SRC_BLOCK:ref:${REF_HASHES[$SRC_HASH]}" >> "$TEMP_DIR/block_map"
            DEDUPLICATED_BLOCKS=$((DEDUPLICATED_BLOCKS + 1))
        else
            # Unique block, extract and save
            dd if="$SOURCE" of="$TEMP_DIR/unique_block.$SRC_BLOCK" bs="$BLOCK_SIZE" skip="$SRC_BLOCK" count=1 2>/dev/null
            echo "$SRC_BLOCK:unique:$SRC_HASH" >> "$TEMP_DIR/block_map"
            UNIQUE_BLOCKS=$((UNIQUE_BLOCKS + 1))
        fi
    done < "$TEMP_DIR/source_hashes"
    
    # Update metadata with block counts
    echo "UNIQUE_BLOCKS=$UNIQUE_BLOCKS" >> "$TEMP_DIR/metadata"
    echo "DEDUPLICATED_BLOCKS=$DEDUPLICATED_BLOCKS" >> "$TEMP_DIR/metadata"
    
    # Package the deduplicated file
    tar -czf "$OUTPUT" -C "$TEMP_DIR" metadata block_map unique_block.* 2>/dev/null
    
    # Clean up
    rm -rf "$TEMP_DIR"
    
    log_message "Deduplication completed: $UNIQUE_BLOCKS unique blocks, $DEDUPLICATED_BLOCKS deduplicated blocks"
    
    # Calculate space savings
    TOTAL_SIZE=$((UNIQUE_BLOCKS * BLOCK_SIZE))
    if [ "$SOURCE_SIZE" -gt 0 ]; then
        SAVINGS=$(( (SOURCE_SIZE - TOTAL_SIZE) * 100 / SOURCE_SIZE ))
        log_message "Space savings: $SAVINGS% (from $SOURCE_SIZE to approximately $TOTAL_SIZE bytes)"
    fi
    
    return 0
}

# Reconstruct a file from its deduplicated form
reconstruct_from_deduplicated() {
    DEDUP_FILE="$1"
    REFERENCE="$2"
    OUTPUT="$3"
    
    log_message "Reconstructing file from deduplicated form $DEDUP_FILE"
    
    if [ ! -f "$DEDUP_FILE" ] || [ ! -f "$REFERENCE" ]; then
        log_message "Error: Deduplicated or reference file does not exist"
        return 1
    fi
    
    # Create temporary directory
    TEMP_DIR="$HASH_DIR/temp_$(date +%s%N)"
    mkdir -p "$TEMP_DIR"
    
    # Extract deduplicated package
    if ! tar -xzf "$DEDUP_FILE" -C "$TEMP_DIR" 2>/dev/null; then
        log_message "Error: Failed to extract deduplicated package"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    # Check if required files exist
    if [ ! -f "$TEMP_DIR/metadata" ] || [ ! -f "$TEMP_DIR/block_map" ]; then
        log_message "Error: Deduplicated package is missing required files"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    # Load metadata
    . "$TEMP_DIR/metadata"
    
    # Create output file
    dd if=/dev/zero of="$OUTPUT" bs=1 count=0 seek="$SOURCE_SIZE" 2>/dev/null
    
    # Apply block map
    while IFS=: read -r SRC_BLOCK TYPE DATA; do
        if [ "$TYPE" = "unique" ]; then
            # Copy unique block from deduplicated package
            if [ -f "$TEMP_DIR/unique_block.$SRC_BLOCK" ]; then
                dd if="$TEMP_DIR/unique_block.$SRC_BLOCK" of="$OUTPUT" bs="$BLOCK_SIZE" seek="$SRC_BLOCK" count=1 conv=notrunc 2>/dev/null
            else
                log_message "Warning: Missing unique block $SRC_BLOCK"
            fi
        elif [ "$TYPE" = "ref" ]; then
            # Copy block from reference
            REF_BLOCK="$DATA"
            dd if="$REFERENCE" of="$OUTPUT" bs="$BLOCK_SIZE" skip="$REF_BLOCK" seek="$SRC_BLOCK" count=1 conv=notrunc 2>/dev/null
        fi
    done < "$TEMP_DIR/block_map"
    
    # Clean up
    rm -rf "$TEMP_DIR"
    
    log_message "File reconstruction completed successfully"
    return 0
}

# Main function - Command processor
main() {
    COMMAND="$1"
    PARAM1="$2"
    PARAM2="$3"
    PARAM3="$4"
    PARAM4="$5"
    
    case "$COMMAND" in
        "diff")
            calculate_binary_diff "$PARAM1" "$PARAM2" "$PARAM3" "$PARAM4"
            ;;
        "apply_diff")
            apply_binary_diff "$PARAM1" "$PARAM2" "$PARAM3"
            ;;
        "compress")
            compress_file "$PARAM1" "$PARAM2" "$PARAM3" "$PARAM4"
            ;;
        "decompress")
            decompress_file "$PARAM1" "$PARAM2" "$PARAM3"
            ;;
        "best_compression")
            select_best_compression "$PARAM1" "$PARAM2"
            ;;
        "hash")
            calculate_hash "$PARAM1"
            ;;
        "block_hash")
            calculate_block_hashes "$PARAM1" "$PARAM2" "$PARAM3"
            ;;
        "deduplicate")
            deduplicate_file "$PARAM1" "$PARAM2" "$PARAM3" "$PARAM4"
            ;;
        "reconstruct")
            reconstruct_from_deduplicated "$PARAM1" "$PARAM2" "$PARAM3"
            ;;
        *)
            log_message "Unknown command: $COMMAND"
            echo "Usage: $0 diff|apply_diff|compress|decompress|best_compression|hash|block_hash|deduplicate|reconstruct [parameters]"
            return 1
            ;;
    esac
}

# Execute main with all arguments
main "$@"