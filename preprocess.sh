#!/bin/bash

# -----------------------------------------------------------------------------
# Script: preprocess.sh
#
# Purpose:
#   This script is designed to clean a semicolon-separated data file.
#   It applies several transformations and directs the cleaned data
#   to standard output.
#
# Transformations include:
#   1. Semicolon (;) separators are converted to tab characters (<tab>).
#   2. Microsoft line endings (CRLF) are converted to Unix line endings (LF).
#   3. Floating-point numbers in 'Rating Average' and 'Complexity Average'
#      columns are standardized to use a dot (.) for the decimal point,
#      replacing commas (,).
#   4. Non-ASCII characters are removed from the output.
#   5. New, unique integer IDs are generated for rows with an empty 'ID' field.
#      Generation starts from 1 greater than the maximum existing numeric ID.
#
# Usage:
#   ./preprocess.sh <input_file>
#
# Example:
#   ./preprocess.sh bgg_dataset.txt > bgg_dataset_cleaned.tsv
#
# Input:
#   $1 (input_file): Path to the semicolon-separated text file for cleaning.
#
# Output:
#   The cleaned, tab-separated data is printed to standard output.
#   This output is typically redirected to a new file.
#
# Assumptions:
#   - The input file uses semicolons (;) as column separators.
#   - The first line contains column headers.
#   - The 'ID' column is the first column.
# -----------------------------------------------------------------------------


# --- Validating script arguments and input file status ---
if [ "$#" -ne 1 ]; then
    echo "Error: Incorrect number of arguments supplied." >&2 # Notifies about incorrect argument count.
    echo "Usage: $0 <input_file>" >&2
    exit 1
fi

input_file="$1" # Assigns the first argument to input_file variable.

if [ ! -f "$input_file" ]; then
    echo "Error: Input file '$input_file' does not exist or is not a regular file." >&2 # Checks if the input file exists and is a regular file.
    exit 1
fi

# --- Preparatory actions for ID generation and column identification ---
# Step 1: The maximum existing numeric ID in the original file is determined.
# This value is used as a basis for generating new IDs for rows with empty ID fields.
# Awk processes the input file, using semicolon as a field separator.
max_id_val=$(awk -F';' '
    BEGIN { max=0 } # Initializes `max` to 0 before processing lines.
    # For data lines (NR > 1) where the first field ($1) is purely numeric:
    NR > 1 && $1 ~ /^[0-9]+$/ {
        # If the numeric value of the first field is greater than current `max`:
        if (int($1) > max) max = int($1); # `max` is updated.
    }
    END { print max } # After processing all lines, the final `max` value is printed.
' "$input_file")


# If no numeric IDs were found in the file, `max_id_val` might be empty or 0.
# It defaults to 0 in such cases, ensuring `current_new_id` starts from 1.
if [ -z "$max_id_val" ]; then
    max_id_val=0
fi
current_new_id=$((max_id_val + 1)) # Sets the starting number for new IDs.

# Step 2: The header line is read to identify indices of specific columns.
# This allows targeted transformations (e.g., float format changes) later.
# The first line of the input file is extracted, and any leading BOM is removed.
header_line=$(head -n 1 "$input_file" | sed 's/^\xEF\xBB\xBF//')

# The Internal Field Separator (IFS) is temporarily changed to semicolon
# to correctly split the header line into an array of column names.
OLD_IFS="$IFS"
IFS=';'
# The header line is read into the `header_cols_array`.
# shellcheck disable=SC2206 # Word splitting is intended here.
read -r -a header_cols_array <<< "$header_line"
IFS="$OLD_IFS" # IFS is restored to its original value.

# Column indices (1-based for awk) are determined. Initialized to -1 (not found).
id_col_idx=-1
rating_avg_col_idx=-1
complexity_avg_col_idx=-1

# Iterating through the array of header column names.
for i in "${!header_cols_array[@]}"; do
    col_name_raw="${header_cols_array[$i]}" # Gets the raw column name.
    # The column name is cleaned: leading/trailing whitespace and trailing \r are removed.
    col_name_cleaned=$(echo "$col_name_raw" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/\r$//')
    
    # Assigns column index if a match is found.
    if [[ "$col_name_cleaned" == "/ID" ]]; then id_col_idx=$((i + 1)); fi
    if [[ "$col_name_cleaned" == "Rating Average" ]]; then rating_avg_col_idx=$((i + 1)); fi
    if [[ "$col_name_cleaned" == "Complexity Average" ]]; then complexity_avg_col_idx=$((i + 1)); fi
done

# A critical check: if the 'ID' column was not found, the script cannot proceed reliably.
if [[ $id_col_idx -eq -1 ]]; then
    echo "Error: 'ID' column not found in header of $input_file." >&2
    exit 1
fi
# Note: 'Rating Average' and 'Complexity Average' columns might not be present in all test files;
# the awk script is designed to handle their absence if their indices remain -1.


# --- Core data transformations performed by AWK ---
# Bash variables (column indices, next ID value) are passed to awk using -v.
# BEGIN block: Sets awk's internal Field Separator (FS) for input (semicolon)
#              and Output Field Separator (OFS) for output (tab).
#              Initializes awk's internal counter for new ID assignment.
# NR == 1 block (Header processing):
#   - The line is rebuilt using the new OFS (tab), effectively converting separators.
#   - The modified header line is printed.
#   - `next` skips further processing for this line.
# Main block (Data line processing, NR > 1):
#   - The ID field ($id_col) is trimmed of leading/trailing whitespace.
#   - If the trimmed ID field is empty, a new unique ID is assigned.
#   - For 'Rating Average' and 'Complexity Average' columns (if valid indices found):
#     Commas (,) used as decimal points are replaced with dots (.).
#   - The entire data line is rebuilt using OFS (tab) and printed.
awk -v id_col="$id_col_idx" \
    -v next_id_val="$current_new_id" \
    -v rating_col="$rating_avg_col_idx" \
    -v complexity_col="$complexity_avg_col_idx" \
'BEGIN {
    FS=";"; # Input fields are defined as semicolon-separated.
    OFS="\t"; # Output fields will be tab-separated.
    current_id_to_assign = next_id_val; # Sequence for new IDs is initialized.
}
# Processing the first line (NR == 1), identified as the header.
NR == 1 {
    # Rebuilding the line with OFS (tab) converts separators for the header.
    $1 = $1; # This assignment forces awk to re-evaluate $0 using OFS.
    print $0; # The transformed header line is printed.
    next; # Header processing ends; execution moves to the next input line.
}
# For all subsequent lines (data records).
{
    # The ID field ($id_col_idx) of the current row is cleaned of surrounding whitespace.
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", $id_col);
    # If the ID field is empty after cleaning:
    if ($id_col == "") {
        $id_col = current_id_to_assign++; # A new ID is assigned from the sequence.
    }

    # Floating-point number conversion for "Rating Average".
    # This occurs if rating_col is a valid index (greater than 0 and within current line field count NF).
    if (rating_col > 0 && rating_col <= NF) {
        gsub(",", ".", $rating_col); # Commas are replaced with dots.
    }
    # Similar conversion for "Complexity Average".
    if (complexity_col > 0 && complexity_col <= NF) {
        gsub(",", ".", $complexity_col);
    }
    
    $1 = $1; # The current data line is rebuilt using tab separators and updated field values.
    print $0; # The cleaned data line is printed.
}' "$input_file" | \
# --- Post-AWK stream editing for final cleanup ---
# 1. Line ending conversion: Any remaining Microsoft-style CRLF endings are converted to Unix LF.
#    `sed` removes a carriage return (\r) if it is the last character of a line.
sed 's/\r$//' | \
# 2. Non-ASCII character removal: All non-ASCII characters are deleted from the stream.
#    `tr -cd '\11\12\40-\176'` retains Tab (octal 11), Newline (octal 12),
#    and printable ASCII characters (Space, octal 40, through Tilde, octal 176).
tr -cd '\11\12\40-\176'
