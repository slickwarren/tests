#!/bin/bash

# for debugging, but also skips errors if they occur in this script (we want to skip)
error_handler() {
  local lineno=${BASH_LINENO[0]}
  
  local funcname=${FUNCNAME[1]}
  
  local command=${BASH_COMMAND}

  # uncomment to debug errors
  # echo "Error occurred at line $lineno in function $funcname: '$command'"
}

trap error_handler ERR

TARGET_BRANCH="main"
TEMP_DIR=$(mktemp -d)

grep-for-suite-and-test-name() {

    suite_name=$(echo "$1" | grep func | grep -oP '\((.*?)\)' | grep -oP '\*\K\w+' | grep -v "testing" | grep -v "github.com")
    test_name=$(echo "$1" | grep -oP 'func \(\w+\s\*\w+\) \K\w+' | grep -v "github.com")
    
    if [[ -n "$suite_name" && -n "$test_name" ]]; then
        echo "$suite_name $test_name"
    fi
}

touch $TEMP_DIR/diff.used-anywhere
git diff origin/$TARGET_BRANCH | while read line; do
    grep-for-suite-and-test-name "$line" >> $TEMP_DIR/diff.used-anywhere
done

echo "Modified Tests:"
cat $TEMP_DIR/diff.used-anywhere
# Clean up
rm -rf $TEMP_DIR
