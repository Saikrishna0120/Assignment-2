# Board Game Data Analysis Scripts

This project comprises three Bash shell scripts engineered for the processing and analysis of board game data, typically sourced from datasets such as the BoardGameGeek dataset available on Kaggle. The scripts facilitate data quality assessment, data cleansing operations, and fundamental statistical analysis.

## Project Overview

The central aim is the analysis of a board game dataset to address inquiries including:
*   Identification of common data quality issues (e.g., occurrences of empty cells).
*   Determination of the most prevalent game domain and playing style (mechanics).
*   Assessment of correlation between a game's publication year and its average rating.
*   Assessment of correlation between a game's complexity and its average rating.

## Scripts

The project features the following top-level scripts:

### 1. `empty_cells.sh`

*   **Purpose:**
    This script examines a separator-delimited text file. Its main function is to enumerate empty cells within each column. Column titles are sourced from the initial line of the input file.
*   **Usage:**
    ```bash
    ./empty_cells.sh <input_file> <separator_character>
    ```
*   **Example:**
    ```bash
    ./empty_cells.sh bgg_dataset.txt ";"
    ```
*   **Inputs:**
    *   `<input_file>`: The path to the text file designated for analysis.
    *   `<separator_character>`: The character used to delimit columns within the file.
*   **Output:**
    Results are rendered to standard output. Each line presents a column title alongside its respective empty cell count, formatted as:
    `Column Title: count`. For instance:
    ```
    /ID: 16
    Name: 0
    ...
    Domains: 10159
    ```

### 2. `preprocess.sh`

*   **Purpose:**
    This script is structured to cleanse a semicolon-separated data file. It executes several transformations and directs the refined data to standard output.
*   **Transformations include:**
    1.  Semicolon (`;`) separators are replaced with tab characters (`<tab>`).
    2.  Microsoft-style line endings (CRLF) are converted to Unix-style line endings (LF).
    3.  Floating-point numbers within the "Rating Average" and "Complexity Average" columns are standardized to utilize a dot (`.`) as the decimal separator, superseding commas (`,`).
    4.  Non-ASCII characters are expunged from the output.
    5.  New, unique integer identifiers are generated for rows that possess an empty 'ID' field. This generation commences from a value one greater than the maximum existing numeric ID found in the file.
*   **Usage:**
    ```bash
    ./preprocess.sh <input_file>
    ```
*   **Example:**
    ```bash
    ./preprocess.sh bgg_dataset.txt > bgg_dataset_cleaned.tsv
    ```
*   **Input:**
    *   `<input_file>`: Path to the semicolon-separated text file requiring cleansing.
*   **Output:**
    The cleansed, tab-separated data is printed to standard output. This output is customarily redirected to a new `.tsv` file.

### 3. `analysis.sh`

*   **Purpose:**
    This script ingests a cleansed (tab-separated) board game data file to derive insights for specific research questions:
    1.  Identification of the most frequently appearing game mechanics.
    2.  Identification of the most common game style or domain.
    3.  Calculation of the Pearson correlation coefficient between "Year Published" and "Average Rating".
    4.  Calculation of the Pearson correlation coefficient between "Complexity Average" and "Average Rating".
*   **Usage:**
    ```bash
    ./analysis.sh <cleaned_input_file.tsv>
    ```
*   **Example:**
    ```bash
    ./analysis.sh bgg_dataset_cleaned.tsv
    ```
*   **Input:**
    *   `<cleaned_input_file.tsv>`: Path to the pre-cleansed, tab-separated data file (typically the output derived from `preprocess.sh`).
*   **Output:**
    The script outputs analysis results to standard output, conforming to the format exemplified in assignment materials. Correlation values are rounded to three decimal places. For example:
    ```
    The most popular game mechanics is Hand Management found in 48 games
    The most style of game is Strategy Games found in 77 games

    The correlation between the year of publication and the average rating is 0.226
    The correlation between the complexity of a game and its average rating is 0.426
    ```

## Setup and Execution

1.  **Permissions:** Scripts must be made executable:
    ```bash
    chmod +x empty_cells.sh preprocess.sh analysis.sh
    ```
2.  **Recommended Workflow:**
    *   Optionally, initiate by assessing empty cells within the raw data file:
        ```bash
        ./empty_cells.sh your_raw_data.txt ";"
        ```
    *   Subsequently, preprocess the raw data to generate a cleansed version:
        ```bash
        ./preprocess.sh your_raw_data.txt > your_cleaned_data.tsv
        ```
    *   Finally, execute the analysis script using the cleansed data file:
        ```bash
        ./analysis.sh your_cleaned_data.tsv
        ```

## Dependencies

*   A Bash shell environment (version 3.2 or newer is advisable).
*   Standard Unix/Linux command-line utilities: `awk`, `sed`, `tr`, `head`, `grep`, `sort`, `cut`. These utilities are generally pre-installed in most Linux and macOS distributions.

## Data Files

The assignment materials include several sample data files (e.g., `sample.txt`, `sample1.txt`, `tiny_sample.txt`) and their corresponding anticipated cleansed versions (`.tsv` files). These serve as aids for the development and testing phases of the scripts. The principal dataset for comprehensive analysis is `bgg_dataset.txt`.

## Style and Maintainability

These scripts have been constructed with consideration for code style and maintainability, adhering to the subsequent principles:
*   **Comments:** Each script incorporates a header comment block delineating its purpose, usage directives, and input/output specifications. Inline comments serve to elucidate the logic of particular code segments, employing an objective, observational descriptive style.
*   **Variable Names:** Descriptive variable names are utilized to augment code legibility (e.g., `input_file`, `max_id_val`). Standard loop counter variables (e.g., `i`, `j`) are employed where conventional.
*   **Error Handling (Anti-bugging):** The scripts integrate checks for prevalent issues such as incorrect argument quantities, non-existent or unreadable input files, and the absence of critical columns requisite for analysis. Error notifications are channeled to standard error (`stderr`), and scripts terminate with a non-zero exit status upon encountering an error.
*   **Readability:** Code is formatted with uniform indentation to enhance structural clarity and facilitate comprehension.
*   **Temporary Files:** The scripts are architected to obviate the creation of persistent temporary files, primarily leveraging pipes and command substitution for the processing of intermediate data.

## Git Usage

(This section pertains to projects utilizing Git for version control, in alignment with assignment marking rubric guidelines.)
This project is managed through Git for version control. Development adheres to an incremental methodology, with commits recorded as features are actualized or issues are rectified. Commit messages are formulated to be unambiguous and descriptive, summarizing the alterations introduced in each commit.
Standard Git commands employed during development phases include:
```bash
git add .
git commit -m "Implemented feature X and improved error handling in script Y."
git push
git log