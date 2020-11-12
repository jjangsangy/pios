#!/usr/bin/env bash

declare INFO_URL='https://changelogs.ubuntu.com/raspi/os_list_imagingutility_ubuntu.json'

# Image Type [Server | Desktop]
declare IMG_TYPE='Server'

# Ubuntu Version [20.04 | 20.10]
declare VERSION='20.10'

# Machine Architecture: [armhf | arm64]
declare MACHINE='arm64'

function query {
    local q="${1:-'.'}"
    local obj="${2:-${IMG_INFO}}"
    jq -r "${q}" <<< "${obj}"
}

function errecho {
    echo "$(tput setaf 1)${*}$(tput sgr0)" >&2
}

function archive_name {
    local download_url="$(query '.url')"
    local archive="${download_url##*/}"
    echo "${archive}"
}

function image_name {
    local archive="$(archive_name)"
    local name="${archive%.*}"
    if [ "${archive##*.}" = "zip" ]; then
        local name=${name}.img
    fi
    echo "${name}"
}

function extract {
    if [ -f "$1" ] ; then
        case $1 in
            *.tar.bz2)   tar xvjf "$1"    ;;
            *.tar.gz)    tar xvzf "$1"    ;;
            *.tar.xz)    tar xvJf "$1"    ;;
            *.lzma)      unlzma "$1"      ;;
            *.bz2)       bunzip2 "$1"     ;;
            *.rar)       unrar x -ad "$1" ;;
            *.gz)        gunzip "$1"      ;;
            *.tar)       tar xvf "$1"     ;;
            *.tbz2)      tar xvjf "$1"    ;;
            *.tgz)       tar xvzf "$1"    ;;
            *.zip)       unzip "$1"       ;;
            *.Z)         uncompress "$1"  ;;
            *.7z)        7z x "$1"        ;;
            *.xz)        pixz -d "$1"     ;;
            *.exe)       cabextract "$1"  ;;
            *)           echo "extract: '$1' - unknown archive method" ;;
        esac
        if [ $? = 0 ] && [ -e "$1" ]; then
            rm -rf ${1}
        fi
    else
        echo "$1 - file does not exist"
    fi
}

function validate_image {
    local filename="${1:-$(archive_name)}"
    local checksum="${2:-$(query '.image_download_sha256')}"

    echo -e "Validating Image"
    echo -e "  filename: $(tput setaf 6)${filename}$(tput sgr0)"
    echo -e "  checksum: $(tput setaf 2)${checksum}$(tput sgr0)\n"

    sha256sum --check <<< "${checksum} ${filename}"
}

function download_image {
    local download_url="$(query '.url')"
    local archive="$(archive_name)"
    local checksum="$(query '.image_download_sha256')"
    local size="$(query '.image_download_size')"
    local flag=false

    echo "Downloading image to $(tput setaf 6)${archive}$(tput sgr0)"
    echo "$(tput setaf 2)${download_url}$(tput sgr0)"
    curl -SL -o "${archive}" "${download_url}"

    if [ "${checksum}" = "null" ] && [ "${size}" != "null" ]; then
        local flag=true
    elif validate_image "${archive}" "${checksum}"; then
        local flag=true
    fi

    if ${flag}; then
        echo "Unpacking archive"
        extract ${archive} && echo -e "$(tput setaf 2)Success$(tput sgr0)\n"
    fi
}

function write_image {
    local filename=${1:-$(image_name)}
    if hdiutil attach -mountpoint boot "${filename}"; then
        rsync -avu --progress \
            --exclude 'write_image.sh' \
            --exclude '*.img' \
            --exclude 'os_list.json' \
            --exclude boot \
            --exclude apps \
                * boot/
        touch boot/ssh
        hdiutil detach boot
    else
        errecho "Issue mounting image"
    fi
}

function run_all {
    set -euo pipefail
    local filename=$(image_name)
    if ! [ -e "${filename}" ]; then
        download_image
    fi
    write_image "${filename}"
}

declare -x IMG_INFO=$(curl -LSs ${INFO_URL} | jq -r "[.os_list[] | select(.name | test(\"${IMG_TYPE} ${VERSION}\")) | select(.url | test(\"${MACHINE}\"))][0]")
declare -A INFO=(
    [name]="$(query '.name')"
    [url]="$(query '.url')"
    [archive]="$(query '.url | split("/")[-1]')"
    [filename]="$(query '.url | split("/")[-1] | split(".")[:-1] | join("")')"
    [sha256sum]="$(query '.image_download_sha256')"
)

if [ "${0}" = "${BASH_SOURCE}" ]; then
    if [ "${OSNAME}" = "Darwin" ]; then
        $@
    else
        errecho "Script only works on MacOS"
    fi
fi
