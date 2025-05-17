#!/bin/bash

# -----------------------------------------------------------------------------
# Script: empty_cells.sh
#
# Purpose:
#   This script analyzes a separator-delimited text file. Its primary
#   function is to count the occurrences of empty cells within each column.
#   Column titles are determined from the first line of the input file.
#
# Usage:
#   ./empty_cells.sh <input_file> <separator_character>
#
# Example:
#   ./empty_cells.sh bgg_dataset.txt ";"
#
# Inputs:
#   $1 (input_file): The path to the text file for analysis.
#   $2 (separator_character): The character delimiting columns in the file.
#
# Outputs:
#   Results are printed to standard output. Each line presents a column
#   title and its corresponding empty cell count, formatted as:
#   "Column Title: count".
#
# Assumptions:
#   - The first line of the input file contains column headers.
#   - The input is a plain text file.
# -----------------------------------------------------------------------------

# --- Validating script arguments and input file status ---
if [ "$#" -ne 2 ]; then
    echo "Error: Incorrect number of arguments supplied." >&2
    echo "Usage: $0 <input_file> <separator_character>" >&2
    exit 1
fi

input_file="$1"
separator="$2"

if [ ! -f "$input_file" ]; then
    echo "Error: Input file '$input_file' does not exist or is not a regular file." >&2
    exit 1
fi

if [ ! -r "$input_file" ]; then
    echo "Error: Input file '$input_file' cannot be read." >&2
    exit 1
fi

if [ -z "$separator" ]; then
    echo "Error: The separator character argument cannot be empty." >&2
    exit 1
fi

# --- Utilizing AWK for counting empty cells ---
# The field separator for awk is set based on the script's argument.
awk -F"$separator" '
# Processing the first record (NR == 1), identified as the header row.
NR == 1 {
    num_cols = NF; # The number of columns is determined from the header.
    # Iterating through each header field.
    for (i=1; i<=num_cols; i++) {
        col_header = $i; # The current header text is obtained.
        # The first header has any UTF-8 BOM removed, if present.
        if (i == 1) {
            sub(/^\xEF\xBB\xBF/, "", col_header);
        }
        # All headers are cleaned: leading/trailing whitespace and carriage returns are removed.
        gsub(/^[[:space:]]+|[[:space:]\r]+$/, "", col_header);
        titles[i] = col_header; # The cleaned header name is stored.
        counts[i] = 0;          # The empty cell count for this column initializes to zero.
    }
    next; # Processing for the header line concludes; awk moves to the next line.
}
# For subsequent records (data rows)...
{
    # Each column is processed, up to the number of columns identified from the header.
    for (i=1; i<=num_cols; i++) {
        current_field_value = $i; # The content of the current cell is accessed.
        # A trailing carriage return, common in CRLF files, is removed from the field value.
        gsub(/\r$/, "", current_field_value);

        # After cleaning, if the cell is an empty string...
        # (Awk inherently treats fields beyond NF in shorter lines as empty).
        if (current_field_value == "") {
            counts[i]++; # ...the empty cell count for this column is incremented.
        }
    }
}
# After all lines have been processed...
END {
    # The final counts are printed.
    for (i=1; i<=num_cols; i++) {
        print titles[i] ": " counts[i];
    }
}' "$input_file"
