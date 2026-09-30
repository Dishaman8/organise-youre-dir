#!/usr/bin/env bash

# Sort files in the current directory (or an optional directory) by type.
set -u
shopt -s nullglob dotglob globstar

usage() {
    cat <<'USAGE'
Usage: orgnise-dir.sh [DIRECTORY]

Organize regular files immediately inside DIRECTORY into category folders.
WhatsApp photos are numbered, and recognized movies and TV episodes are
renamed and placed in title/season folders. With no argument, the current
working directory is used.
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
        txt|text|md|markdown|rst|csv|tsv|rtf|jsonl|xml|html|htm|css|js|mjs|cjs|ts|tsx|jsx|py|sh|bash|zsh|c|h|cc|cpp|hpp|java|kt|go|rs|rb|php|sql|yaml|yml|toml|ini|cfg|conf)
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

clean_title() {
    local title=$1
    title=${title//./ }
    title=${title//_/ }
    title=${title//[/}
    title=${title//]/}
    title=${title//\(}
    title=${title//\)}
    while [[ $title == *'  '* ]]; do
        title=${title//'  '/ }
    done
    title=${title# }
    title=${title% }
    title=${title%-}
    title=${title% }
    printf '%s' "$title"
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

count_files() {
    local count=0 file
    for file in "$1"/**; do
        [[ -f $file ]] && ((count += 1))
    done
    printf '%d' "$count"
}

found=0
moved=0
failed=0
declare -A moved_files=()
declare -A category_moved=()
for category in "${categories[@]}"; do
    moved_files[$category]=""
    category_moved[$category]=0
done

record_move() {
    local source_file=$1 category=$2 destination_dir=$3 filename=$4 display_name=$5
    local destination
    destination=$(make_destination "$destination_dir" "$filename")
    if mv -- "$source_file" "$destination"; then
        ((moved += 1))
        ((category_moved[$category] += 1))
        moved_files[$category]+="$display_name"$'\n'
    else
        printf 'Could not move: %s\n' "$source_file" >&2
        ((failed += 1))
    fi
}

whatsapp_photo_directory=$target_dir/Photos/WhatsApp\ Photos
next_whatsapp_photo=1
for existing_photo in "$whatsapp_photo_directory"/Photo\ *; do
    [[ -f $existing_photo ]] || continue
    existing_name=${existing_photo##*/}
    if [[ $existing_name =~ ^Photo\ ([0-9]+)\. ]]; then
        existing_number=$((10#${BASH_REMATCH[1]}))
        (( existing_number >= next_whatsapp_photo )) && next_whatsapp_photo=$((existing_number + 1))
    fi
done

normalize_movie_name() {
    local base=$1 normalized token token_lower result="" stopped=0
    normalized=${base//./ }
    normalized=${normalized//_/ }
    local -a tokens=()
    read -r -a tokens <<< "$normalized"
    for token in "${tokens[@]}"; do
        token_lower=${token,,}
        token_lower=${token_lower//[/}
        token_lower=${token_lower//]/}
        case $token_lower in
            480p|576p|720p|1080p|1440p|2160p|4k|8k|web-dl|webdl|webrip|bluray|blu-ray|brrip|bdrip|hdtv|pdtv|dvdrip|x264|x265|h264|h265|hevc|av1|hdr|hdr10|aac|ac3|dts|atmos|proper|repack|limited|yify|yts|rarbg)
                stopped=1
                break ;;
        esac
        if [[ $token_lower =~ ^[0-9]{3,4}p$ ]]; then
            stopped=1
            break
        fi
        result+="${result:+ }$token"
    done
    printf '%s' "$result"
    [[ $stopped == 1 ]]
}

organize_video() {
    local source_file=$1 filename=${1##*/} base extension year title season episode episode_tag
    local series year_prefix
    base=$filename
    extension=""
    if [[ $filename == *.* && $filename != .* ]]; then
        base=${filename%.*}
        extension=.${filename##*.}
    fi
    if [[ $base =~ ^(.+)[[:space:]_.-]*[sS]([0-9]{1,2})[[:space:]_.-]*[eE]([0-9]{1,2}) ]]; then
        series=$(clean_title "${BASH_REMATCH[1]}")
        season=${BASH_REMATCH[2]}
        episode=${BASH_REMATCH[3]}
        if [[ -n $series ]]; then
            season=$((10#$season))
            episode=$((10#$episode))
            episode_tag=$(printf 'S%02dE%02d' "$season" "$episode")
            destination_dir=$target_dir/Videos/TV\ Shows/"$series"/"Season $(printf '%02d' "$season")"
            mkdir -p -- "$destination_dir" || return 1
            record_move "$source_file" "Videos" "$destination_dir" "$series - $episode_tag$extension" "TV Shows/$series/Season $(printf '%02d' "$season")/$series - $episode_tag$extension"
            return 0
        fi
    elif [[ $base =~ ^(.+)[[:space:]_.-]*([0-9]{1,2})[xX]([0-9]{1,2}) ]]; then
        series=$(clean_title "${BASH_REMATCH[1]}")
        season=${BASH_REMATCH[2]}
        episode=${BASH_REMATCH[3]}
        if [[ -n $series ]]; then
            season=$((10#$season))
            episode=$((10#$episode))
            episode_tag=$(printf 'S%02dE%02d' "$season" "$episode")
            destination_dir=$target_dir/Videos/TV\ Shows/"$series"/"Season $(printf '%02d' "$season")"
            mkdir -p -- "$destination_dir" || return 1
            record_move "$source_file" "Videos" "$destination_dir" "$series - $episode_tag$extension" "TV Shows/$series/Season $(printf '%02d' "$season")/$series - $episode_tag$extension"
            return 0
        fi
    fi

    if [[ $base =~ ((19|20)[0-9]{2}) ]]; then
        year=${BASH_REMATCH[1]}
        year_prefix=${base%%"$year"*}
        title=$(clean_title "$year_prefix")
        [[ -n $title ]] && title="$title ($year)" || title=$year
        destination_dir=$target_dir/Videos/Movies/"$title"
        mkdir -p -- "$destination_dir" || return 1
        record_move "$source_file" "Videos" "$destination_dir" "$title$extension" "Movies/$title/$title$extension"
        return 0
    fi

    title=$(normalize_movie_name "$base")
    if [[ -n $title && $title != "$base" ]]; then
        destination_dir=$target_dir/Videos/Movies/"$title"
        mkdir -p -- "$destination_dir" || return 1
        record_move "$source_file" "Videos" "$destination_dir" "$title$extension" "Movies/$title/$title$extension"
    else
        record_move "$source_file" "Videos" "$target_dir/Videos" "$filename" "$filename"
    fi
}

printf 'Current path: %s\n' "$target_dir"
for source_file in "$target_dir"/*; do
    [[ -f $source_file ]] || continue
    [[ $source_file == "$script_path" ]] && continue
    case ${source_file##*/} in
        README.md|README.MD) continue ;;
    esac
    ((found += 1))
    category=$(classify_file "$source_file")
    filename=${source_file##*/}

    if [[ $category == "Photos" && ${filename,,} =~ ^(whatsapp|img[-_ ]?[0-9]{8}[-_ ]?wa|vid[-_ ]?[0-9]{8}[-_ ]?wa) ]]; then
        extension=""
        [[ $filename == *.* && $filename != .* ]] && extension=.${filename##*.}
        destination_dir=$target_dir/Photos/WhatsApp\ Photos
        mkdir -p -- "$destination_dir" || { ((failed += 1)); continue; }
        numbered_name=$(printf 'Photo %03d%s' "$next_whatsapp_photo" "$extension")
        record_move "$source_file" "$category" "$destination_dir" "$numbered_name" "WhatsApp Photos/$numbered_name"
        ((next_whatsapp_photo += 1))
    elif [[ $category == "Videos" ]]; then
        organize_video "$source_file" || { ((failed += 1)); }
    else
        record_move "$source_file" "$category" "$target_dir/$category" "$filename" "$filename"
    fi
done

if [[ -t 1 ]]; then
    color_header=$'\033[1;36m'
    color_total=$'\033[1;32m'
    color_reset=$'\033[0m'
else
    color_header=""
    color_total=""
    color_reset=""
fi

found_unit=file
moved_unit=file
(( found == 1 )) || found_unit=files
(( moved == 1 )) || moved_unit=files
printf '\nFound %d %s in current path.\n' "$found" "$found_unit"
printf 'Organized %d %s successfully.\n\n' "$moved" "$moved_unit"
printf '%s%-24s %10s %10s%s\n' "$color_header" 'CATEGORY' 'IN FOLDER' 'MOVED NOW' "$color_reset"
printf '%-24s %10s %10s\n' '------------------------' '----------' '----------'
for category in "${categories[@]}"; do
    total=$(count_files "$target_dir/$category")
    printf '%s%-24s %10s %10s%s\n' "$color_total" "$category" "$total" "${category_moved[$category]-0}" "$color_reset"
done

for category in "${categories[@]}"; do
    [[ -n ${moved_files[$category]-} ]] || continue
    printf '\n%s files moved this run:\n' "$category"
    while IFS= read -r moved_file; do
        [[ -n $moved_file ]] && printf '  - %s\n' "$moved_file"
    done <<< "${moved_files[$category]}"
done

if (( failed > 0 )); then
    printf '\nWarning: %d of %d files could not be moved.\n' "$failed" "$found" >&2
    exit 1
fi
