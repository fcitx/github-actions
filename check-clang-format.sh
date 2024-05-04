#!/bin/bash
gitroot=$(git rev-parse --show-toplevel 2> /dev/null)

if [[ -z $gitroot ]]; then
    echo "Not running within the root of git repo, exiting..."
    exit 1
fi

cd $gitroot

# Call getopt to validate the provided input.
options=$(getopt -o "" --long list --long format --long print -- "$@")
[ $? -eq 0 ] || {
    echo "Incorrect options provided"
    exit 1
}
RUN_FORMAT=0
PRINT_DIFF=0
eval set -- "$options"
while true; do
    case "$1" in
    --format)
        RUN_FORMAT=1
        ;;
    --print)
        PRINT_DIFF=1
        ;;
    --list)
        LIST_FILE=1
        ;;
    --)
        shift
        break
        ;;
    esac
    shift
done

FORMATS=()

normalize_format() {
    if [[ "$1" =~ ^/ ]]; then
        echo $1
    else
        echo "**/$1"
    fi
}

if [[ -f .formatignore ]]; then
    while read format; do
        if [[ "$format" =~ ^# ]]; then
            continue
        fi
        if [[ -z "$format" ]]; then
            continue
        fi
        FORMATS+=("$(normalize_format $format)")
    done < .formatignore
fi

HAS_DIFF=0

list_all_files() {
    git ls-files | grep '\.\(h\|c\|cpp\|cc\)$' | sort | uniq
}

list_match_files() {
    if [[ ${#FORMATS[@]} -ne 0 ]]; then
        for format in "${FORMATS[@]}"; do
            (shopt -s extglob; shopt -s nullglob; shopt -s globstar; for f in $format; do echo "$f"; done)
        done | sort | uniq
    fi
}

list_files() {
    comm -23 <(list_all_files) <(list_match_files)
}

if [[ "$LIST_FILE" == 1 ]]; then
    list_files
    exit 0
fi

while read file; do
    OUTPUT=/dev/stdout
    if [[ "$PRINT_DIFF" == "0" ]]; then
        OUTPUT=/dev/null
    fi
    if ! diff --label "original/$file" --label "formatted/$file" -u <(cat "$file") <(clang-format "$file") > $OUTPUT; then
        if [[ "$PRINT_DIFF" == "0" && "$RUN_FORMAT" == 0 ]]; then
            echo "$file need to be formatted"
        fi
        if [[ "$RUN_FORMAT" == 1 ]]; then
            echo "Formatting $file"
            if ! clang-format -i "$file"; then
                echo "Failed to format $file"
                exit 1
            fi
        fi
        HAS_DIFF=1
    fi
done < <(list_files)

if [[ "$HAS_DIFF" == 1 && "$RUN_FORMAT" == 0 ]]; then
    exit 1
fi

exit 0
