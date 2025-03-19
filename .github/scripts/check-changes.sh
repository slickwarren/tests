#!/bin/bash

# set -e
error_handler() {
  # Get the line number where the error occurred
  local lineno=${BASH_LINENO[0]}
  
  # Get the function name where the error occurred
  local funcname=${FUNCNAME[1]}  # FUNCNAME[1] gives the name of the calling function
  
  # Get the command that caused the error
  local command=${BASH_COMMAND}

  # Print the error details
  # echo "Error occurred at line $lineno in function $funcname: '$command'"
}

trap error_handler ERR

# Variables
TARGET_BRANCH="main"  # The branch you want to compare to
ACTIONS_DIR="actions" # Directory containing the Go functions
TEMP_DIR=$(mktemp -d)

# find and report on tests changed and tests that used modified actions

grep-for-function-name() {
    echo "$1" | grep func | \
    sed -E 's/.*func[[:space:]]+([a-zA-Z0-9_]+).*/\1/' | \
    grep -v "(" | \
    grep -v "//"
}

# returns a line-by-line list of where each changed function is used anywhere
find-all-functions-anywhere() {
    for function_name in $1 ; do
        # echo "Getting function matches in files..."
        contained_files=$(grep -n -r "$function_name" --exclude-dir=".git" --exclude-dir=".github" . | grep -v "//" | grep -v "go.mod" | grep -v "go.sum" | grep -v "main.go" )
        # echo "$contained_files"
        echo "$contained_files" >> $TEMP_DIR/diff.test-functions
    done
}

grep-for-suite-and-test-name() {
    # Extract Suite Name from ()
    suite_name=$(echo "$1" | grep func | grep -oP '\((.*?)\)' | grep -oP '\*\K\w+' | grep -v "testing" | grep -v "github.com")
    
    # Extract Test Name
    test_name=$(echo "$1" | grep -oP 'func \(\w+\s\*\w+\) \K\w+')
    
    # Output both suite name and test name
    if [[ -n "$suite_name" && -n "$test_name" ]]; then
        echo "$suite_name $test_name"
    fi
}

touch $TEMP_DIR/diff.used-anywhere
git fetch --all
git diff origin/$TARGET_BRANCH | while read line; do
    grep-for-suite-and-test-name "$line" >> $TEMP_DIR/diff.used-anywhere
done

git diff origin/$TARGET_BRANCH | while read line; do
    next=$(grep-for-function-name "$line")
    if [[ $next == *"Test"* ]]; then
        echo $next >> $TEMP_DIR/diff.used-anywhere
    else
        find-all-functions-anywhere $next 
    fi
done

touch $TEMP_DIR/diff.test-functions
while IFS= read -r lines_not_tests; do
    if [[ "$lines_not_tests" != *"func"* && "$lines_not_tests" != *"TestSuite"* ]]; then
        if [[ "$lines_not_tests" == *".go"* ]]; then
        
            line_number=$(echo "$lines_not_tests" | awk -F":" '{print $2}')

            file=$(echo "$lines_not_tests" | awk -F":" '{print $1}')
            # find the parent function that this line belongs to
            function_line=$(head -n "$line_number" "$file" | tac | grep -m 1 '^func' | tac)
            function_name_tmp=$(grep-for-function-name "$function_line")
            # check for new function everywhere. If its a test, add it to the list. 
            
            if [ -n "$function_name_tmp" ]; then
                echo "$function_name_tmp"
                find-all-functions-anywhere "$function_name_tmp"
            fi

            test_name=$(grep-for-suite-and-test-name "$function_line")
            if ! grep -q "$test_name" $TEMP_DIR/diff.used-anywhere; then
                echo "$function_line"
                echo $test_name >> $TEMP_DIR/diff.used-anywhere
            fi
        fi
    # mostly for debugging, outputs non-test functions that are used by modified ones. 
    # else 
    #     new_name=$(grep-for-function-name "$lines_not_tests")

    #     # make sure the function isn't already in the list
    #     if ! grep -q "$new_name" "$TEMP_DIR/diff.used-anywhere"; then
    #         # echo "$lines_not_tests"
    #         echo "$new_name" >> $TEMP_DIR/diff.used-anywhere
    #     fi
        
    fi
done < $TEMP_DIR/diff.test-functions

wait

cat $TEMP_DIR/diff.used-anywhere

# Clean up
rm -rf $TEMP_DIR
