#!/bin/bash

# ---------------------------------------------------------------------------
# Script: analysis.sh
#
# Purpose:
#   This script processes a cleaned (tab-separated) board game data file
#   to derive answers for specific research inquiries:
#   1. Identification of the most frequently occurring game mechanics.
#   2. Identification of the most common game style/domain.
#   3. Calculation of Pearson correlation: Year Published vs. Average Rating.
#   4. Calculation of Pearson correlation: Complexity Average vs. Average Rating.
#
# Usage:
#   ./analysis.sh <cleaned_input_file.tsv>
#
# Example:
#   ./analysis.sh bgg_dataset_cleaned.tsv
#
# Input:
#   $1 (cleaned_input_file.tsv): Path to the pre-cleaned, tab-separated data file.
#
# Outputs:
#   The script prints analysis results to standard output. This includes:
#   - The most popular mechanics and domain, along with their counts.
#   - Correlation coefficients, rounded to three decimal places.
#
# Assumptions:
#   - The input file is tab-separated.
#   - The first line is the header row.
#   - Specific columns ('Year Published', 'Rating Average', 'Complexity Average',
#     'Mechanics', 'Domains') are present in the header.
#   - Numeric data intended for correlation is valid (using dots for decimals).
# -----------------------------------------------------------------------------

# --- Validating script arguments and input file status ---
if [ "$#" -ne 1 ]; then
    echo "Error: Incorrect number of arguments supplied." >&2 # Notifies about incorrect argument count.
    echo "Usage: $0 <cleaned_input_file>" >&2
    exit 1
fi

input_file="$1" # Assigns the first argument to input_file variable.

if [ ! -f "$input_file" ]; then
    echo "Error: Input file '$input_file' does not exist or is not a regular file." >&2 # Checks if the input file exists.
    exit 1
fi

# --- Column Index Identification from Header ---
# The header line is read from the cleaned input file.
# Any leading UTF-8 Byte Order Mark (BOM) is removed from the header line.
header_line=$(head -n 1 "$input_file" | sed 's/^\xEF\xBB\xBF//')

# The Internal Field Separator (IFS) is temporarily set to a tab character
# to correctly split the header line into an array of column names.
OLD_IFS="$IFS"
IFS=$'\t'
# The header line is read into the `cols_array`.
# shellcheck disable=SC2206 # Word splitting is intended here for array creation.
read -r -a cols_array <<< "$header_line"
IFS="$OLD_IFS" # IFS is restored to its original value.

# Column indices (1-based for awk) are initialized to -1 (indicating "not found").
year_col_idx=-1
rating_avg_col_idx=-1
complexity_avg_col_idx=-1
mechanics_col_idx=-1
domains_col_idx=-1

# Iterating through the array of header column names to find required columns.
for i in "${!cols_array[@]}"; do
    col_name_raw="${cols_array[$i]}" # Obtains the raw column name.
    # The column name is cleaned: leading/trailing whitespace and trailing \r are removed.
    col_name_cleaned=$(echo "$col_name_raw" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/\r$//')

    # The cleaned column name is compared against expected names to set indices.
    case "$col_name_cleaned" in
        "Year Published") year_col_idx=$((i + 1));;
        "Rating Average") rating_avg_col_idx=$((i + 1));;
        "Complexity Average") complexity_avg_col_idx=$((i + 1));;
        "Mechanics") mechanics_col_idx=$((i + 1));;
        "Domains") domains_col_idx=$((i + 1));;
    esac
done

# Critical validation: Checks if all required columns for analysis were successfully identified.
if [[ $year_col_idx -eq -1 || $rating_avg_col_idx -eq -1 || $complexity_avg_col_idx -eq -1 || $mechanics_col_idx -eq -1 || $domains_col_idx -eq -1 ]]; then
    echo "Error: One or more required columns (Year Published, Rating Average, Complexity Average, Mechanics, Domains) not found in header of $input_file." >&2
    # Provides specific feedback about which columns are missing.
    [[ $year_col_idx -eq -1 ]] && echo "Missing: Year Published" >&2
    [[ $rating_avg_col_idx -eq -1 ]] && echo "Missing: Rating Average" >&2
    [[ $complexity_avg_col_idx -eq -1 ]] && echo "Missing: Complexity Average" >&2
    [[ $mechanics_col_idx -eq -1 ]] && echo "Missing: Mechanics" >&2
    [[ $domains_col_idx -eq -1 ]] && echo "Missing: Domains" >&2
    exit 1 # Exits if any critical column is missing.
fi

# --- Part 1: Determining Most Popular Mechanics and Domains ---
# An awk script processes the input file to count occurrences of each mechanic and domain.
# Mechanics and Domains cells can contain comma-separated lists of items.
# Column indices for Mechanics (mcol) and Domains (dcol) are passed to awk.
# Special marker lines (e.g., "---MECHANICS_COUNTS_START---") are used in awk's output
# to help the shell script parse the counts for mechanics and domains separately.
counts_output=$(awk -F'\t' \
    -v mcol="$mechanics_col_idx" \
    -v dcol="$domains_col_idx" '
    # Awk function: Removes leading and trailing whitespace from a string.
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s; }
    
    # Processing data lines only (NR > 1 skips the header row).
    NR > 1 {
        # Processing the "Mechanics" column for the current game.
        # This occurs if mcol is a valid index and the cell is not empty.
        if (mcol > 0 && mcol <= NF && $mcol != "") {
            # The content of the Mechanics cell is split by commas into an array.
            num_mechanics = split($mcol, mech_array, /,/);
            # Iterating through each parsed mechanic.
            for (j=1; j<=num_mechanics; j++) {
                current_mech = trim(mech_array[j]); # The mechanic string is trimmed.
                if (current_mech != "") {           # If not empty after trimming:
                    mechanic_counts[current_mech]++; # Its count is incremented.
                }
            }
        }
        
        # Similar processing for the "Domains" column.
        if (dcol > 0 && dcol <= NF && $dcol != "") {
            num_domains = split($dcol, domain_array, /,/);
            for (k=1; k<=num_domains; k++) {
                current_domain = trim(domain_array[k]);
                if (current_domain != "") {
                    domain_counts[current_domain]++;
                }
            }
        }
    }
    # END block: Executed after all input lines are processed by awk.
    END {
        # Mechanic counts are printed, preceded by a specific marker line.
        print "---MECHANICS_COUNTS_START---";
        for (mech in mechanic_counts) {
            print mech "\t" mechanic_counts[mech];
        }
        # Domain counts are printed, also preceded by a marker.
        print "---DOMAINS_COUNTS_START---";
        for (dom in domain_counts) {
            print dom "\t" domain_counts[dom];
        }
    }' "$input_file")

# The shell script now processes awk's output to identify the most popular mechanic.
# `sed` extracts the lines corresponding to mechanics counts (between the markers).
# `grep -v -e PATTERN` filters out the marker lines themselves.
mechanics_data=$(echo "$counts_output" | sed -n '/---MECHANICS_COUNTS_START---/,/---DOMAINS_COUNTS_START---/p' | grep -v -e '---MECHANICS_COUNTS_START---' | grep -v -e '---DOMAINS_COUNTS_START---')
if [ -n "$mechanics_data" ]; then # Checks if any mechanics data was extracted.
    # The extracted mechanics data is sorted:
    # Primary sort: by count (column 2, numeric, reverse order for descending).
    # Secondary sort (for ties): by name (column 1, lexicographical).
    # `head -n 1` selects the top entry after sorting (the most popular).
    most_popular_mechanic_line=$(echo "$mechanics_data" | sort -t$'\t' -k2,2nr -k1,1 | head -n 1)
    if [ -n "$most_popular_mechanic_line" ]; then # Ensures a line was actually found by sort.
        pop_mech_name=$(echo "$most_popular_mechanic_line" | cut -f1) # Extracts the name.
        pop_mech_count=$(echo "$most_popular_mechanic_line" | cut -f2) # Extracts the count.
        echo "The most popular game mechanics is $pop_mech_name found in $pop_mech_count games"
    else
        # This case might occur if mechanics_data was not empty but sort yielded no lines (e.g., malformed data).
        echo "No mechanics data available to determine the most popular."
    fi
else
    # This case occurs if the awk script produced no mechanics counts.
    echo "No mechanics data found or an error occurred processing mechanics."
fi

# Similar processing for identifying the most popular domain.
# `sed` extracts lines from the domain marker to the end of awk's output.
domains_data=$(echo "$counts_output" | sed -n '/---DOMAINS_COUNTS_START---/,$p' | grep -v -e '---DOMAINS_COUNTS_START---')
if [ -n "$domains_data" ]; then
    most_popular_domain_line=$(echo "$domains_data" | sort -t$'\t' -k2,2nr -k1,1 | head -n 1)
    if [ -n "$most_popular_domain_line" ]; then
        pop_domain_name=$(echo "$most_popular_domain_line" | cut -f1)
        pop_domain_count=$(echo "$most_popular_domain_line" | cut -f2)
        # "style of game" is interpreted as referring to the Domain.
        echo "The most style of game is $pop_domain_name found in $pop_domain_count games"
    else
        echo "No domains data available to determine the most popular."
    fi
else
    echo "No domains data found or an error occurred processing domains."
fi
echo "" # An empty line is printed for formatting, matching example output.

# --- Part 2: Correlation Calculations ---
# A shell function is defined to encapsulate the Pearson correlation calculation logic using awk.
calculate_correlation() {
    local data_file="$1"    # Input file for correlation.
    local x_col_idx="$2"  # Column index for the X variable.
    local y_col_idx="$3"  # Column index for the Y variable.

    # Awk script for Pearson correlation:
    # - F '\t': Sets tab as the field separator.
    # - xcol, ycol: Variables passed from the shell function.
    # - is_numeric(): An awk function to validate if a string represents a number.
    # - NR > 1: Skips the header row.
    # - Calculates sums (sum_x, sum_y, sum_x_sq, sum_y_sq, sum_xy) and count (N)
    #   for valid numeric pairs.
    # - END block: Computes correlation if N >= 2 and variance terms are positive.
    #   Outputs "0.000" for insufficient data or calculation issues.
    #   Otherwise, prints correlation rounded to 3 decimal places.
    awk -F'\t' -v xcol="$x_col_idx" -v ycol="$y_col_idx" '
    # Awk function: Validates if a value appears to be a number (integer or float).
    # Allows optional sign, digits, optional decimal point with more digits.
    function is_numeric(val) {
        return val ~ /^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$/;
    }
    
    # Processing data lines.
    NR > 1 {
        val_x = $xcol; # Value from X column.
        val_y = $ycol; # Value from Y column.
        
        # Proceeds only if both values are non-empty and appear numeric.
        if (val_x != "" && val_y != "" && is_numeric(val_x) && is_numeric(val_y)) {
            N++; # Increments count of valid pairs.
            # Values are explicitly treated as numbers for summation.
            sum_x += val_x + 0;
            sum_y += val_y + 0;
            sum_x_sq += (val_x + 0) * (val_x + 0);
            sum_y_sq += (val_y + 0) * (val_y + 0);
            sum_xy += (val_x + 0) * (val_y + 0);
        }
    }
    # After all lines are processed.
    END {
        if (N < 2) { # Correlation calculation requires at least two data points.
            printf "0.000\n"; 
            exit; # Exits awk.
        }
        
        numerator = (N * sum_xy) - (sum_x * sum_y);
        denominator_x_term = (N * sum_x_sq) - (sum_x * sum_x);
        denominator_y_term = (N * sum_y_sq) - (sum_y * sum_y);
        
        # Handles cases of zero variance or potential division by zero / sqrt of negative.
        if (denominator_x_term <= 0 || denominator_y_term <= 0) {
            printf "0.000\n";
        } else {
            correlation = numerator / sqrt(denominator_x_term * denominator_y_term);
            printf "%.3f\n", correlation; # Prints correlation rounded to 3 decimal places.
        }
    }' "$data_file"
}

# The calculate_correlation function is called for the two required correlations.
corr_year_rating=$(calculate_correlation "$input_file" "$year_col_idx" "$rating_avg_col_idx")
corr_complexity_rating=$(calculate_correlation "$input_file" "$complexity_avg_col_idx" "$rating_avg_col_idx")

# The calculated correlation results are printed.
echo "The correlation between the year of publication and the average rating is $corr_year_rating"
echo "The correlation between the complexity of a game and its average rating is $corr_complexity_rating"
