#!/usr/bin/env bash

# Sort files in the current directory (or an optional directory) by extension.
set -u

usage() {
    cat <<'USAGE'
Usage: orgnise-dir.sh [DIRECTORY]

Organize regular files immediately inside DIRECTORY into category folders.
If DIRECTORY is omitted, the current working directory is used.
USAGE
}

if [[ ${1-} == "-h" || ${1-} == "--help" ]]; then
    usage
    exit 0
fi
if (( $# > 1 )); then
    usage >&2
    exit 2
fi

requested_dir=${1:-.}
if [[ ! -d $requested_dir ]]; then
    printf 'Error: not a directory: %s\n' "$requested_dir" >&2
    exit 2
fi
target_dir=$(cd -- "$requested_dir" && pwd -P) || exit 2
case $0 in
    /*) script_path=$0 ;;
    *)
        script_dir=${0%/*}
        [[ $script_dir == "$0" ]] && script_dir=.
        script_path=$(cd -- "$script_dir" && pwd -P)/${0##*/}
        ;;
esac

categories=("Photos" "Videos" "Text Files" "App Image Files" "DKBG Files" "PDF Files" "Microsoft Files" "Token Files" "Others")
for category in "${categories[@]}"; do
    if ! mkdir -p -- "$target_dir/$category"; then
        printf 'Error: could not create category directory: %s\n' "$target_dir/$category" >&2
        exit 1
    fi
done

classify_file() {
    local filename=${1##*/}
    local extension=${filename##*.}
    if [[ $filename == .* && $filename != *.*.* ]]; then
        extension=${filename#.}
    elif [[ $filename != *.* ]]; then
        extension=""
    fi
    extension=${extension,,}
    case $extension in
        jpg|jpeg|png|gif|bmp|tif|tiff|webp|heic|heif|avif|raw|cr2|nef|arw|svg|ico)
            printf '%s' "Photos" ;;
        mp4|m4v|mkv|mov|avi|wmv|flv|webm|mpg|mpeg|3gp|ts|mts)
            printf '%s' "Videos" ;;
        txt|text|md|markdown|rst|csv|tsv|rtf|logtxt|jsonl|xml|html|htm|css|js|mjs|cjs|ts|tsx|jsx|py|sh|bash|zsh|c|h|cc|cpp|hpp|java|kt|go|rs|rb|php|sql|yaml|yml|toml|ini|cfg|conf)
            printf '%s' "Text Files" ;;
        appimage|exe|msi|msix|appx|deb|rpm|dmg|pkg|apk|ipa|iso|img|run)
            printf '%s' "App Image Files" ;;
        dkbg|log|debug|stackdump|dmp|dump|trace|core)
            printf '%s' "DKBG Files" ;;
        pdf)
            printf '%s' "PDF Files" ;;
        doc|docx|docm|dot|dotx|dotm|xls|xlsx|xlsm|xlsb|xlt|xltx|ppt|pptx|pptm|pps|ppsx|pot|potx|accdb|mdb|one|pub)
            printf '%s' "Microsoft Files" ;;
        token|tokens|credential|credentials|secret|secrets|pem|key|p12|pfx|env)
            printf '%s' "Token Files" ;;
        *) printf '%s' "Others" ;;
    esac
}

make_destination() {
    local directory=$1 filename=$2 candidate="$1/$2" stem suffix number=1
    if [[ ! -e $candidate ]]; then
        printf '%s' "$candidate"
        return
    fi
    if [[ $filename == *.* && $filename != .* ]]; then
        stem=${filename%.*}
        suffix=.${filename##*.}
    else
        stem=$filename
        suffix=""
    fi
    while [[ -e $directory/$stem\ \($number\)$suffix ]]; do
        ((number += 1))
    done
    printf '%s/%s (%d)%s' "$directory" "$stem" "$number" "$suffix"
}

found=0
moved=0
failed=0
declare -A moved_files=()

count_files() {
    local count=0 file
    for file in "$1"/* "$1"/.[!.]* "$1"/..?*; do
        [[ -f $file ]] && ((count += 1))
    done
    printf '%d' "$count"
}

printf 'Current path: %s\n' "$target_dir"
for source_file in "$target_dir"/* "$target_dir"/.[!.]* "$target_dir"/..?*; do
    [[ -f $source_file ]] || continue
    [[ $source_file == "$script_path" ]] && continue
    case ${source_file##*/} in
        README.md|README.MD) continue ;;
    esac
    ((found += 1))
    category=$(classify_file "$source_file")
    destination_dir=$target_dir/$category
    destination=$(make_destination "$destination_dir" "${source_file##*/}")
    if mv -- "$source_file" "$destination"; then
        ((moved += 1))
        moved_files[$category]+="${destination##*/}"$'\n'
    else
        printf 'Could not move: %s\n' "$source_file" >&2
        ((failed += 1))
    fi
done

printf 'Found %d files in current path.\n' "$found"
printf 'Organized %d files successfully.\n' "$moved"
for category in "${categories[@]}"; do
    printf '\n%s (%s):\n' "$category" "$(count_files "$target_dir/$category")"
    if [[ -n ${moved_files[$category]-} ]]; then
        while IFS= read -r filename; do
            [[ -n $filename ]] && printf '  %s\n' "$filename"
        done <<< "${moved_files[$category]}"
    else
        printf '  (no new files)\n'
    fi
done

if (( failed > 0 )); then
    printf 'Warning: %d of %d files could not be moved.\n' "$failed" "$found" >&2
    exit 1
fi
