#!/bin/sh
set -eu

update=false
case "${1:-}" in
    '') ;;
    --update) update=true ;;
    --help)
        printf '%s\n' 'Usage: sh install.sh [--update]' \
            'Install the shared Ramp setup and Ronna plugin through Git.' \
            '--update fetches the configured versions without changing your configuration.'
        exit 0
        ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 1 ;;
esac
if [ "$#" -gt 1 ]; then
    printf '%s\n' 'Usage: sh install.sh [--update]' >&2
    exit 1
fi

case "${XDG_DATA_HOME:-}" in
    /*) data_home=$XDG_DATA_HOME ;;
    *) data_home=${HOME:?HOME must be set}/.local/share ;;
esac
packages=$data_home/ramp/plugins
mkdir -p "$packages"

install_package() {
    name=$1
    repository=$2
    ref=$3
    destination=$packages/$name
    if [ -e "$destination" ]; then
        if [ ! -d "$destination/.git" ]; then
            printf 'Not a Git checkout: %s\n' "$destination" >&2
            exit 1
        fi
        origin=$(git -C "$destination" remote get-url origin)
        if [ "$origin" != "$repository" ]; then
            printf 'Unexpected origin for %s: %s\n' "$name" "$origin" >&2
            exit 1
        fi
        if [ -n "$(git -C "$destination" status --porcelain)" ]; then
            printf 'Keep or commit your local changes before updating: %s\n' "$destination" >&2
            exit 1
        fi
        if [ "$update" = true ]; then
            git -C "$destination" fetch --depth 1 origin "refs/tags/$ref:refs/tags/$ref"
            git -C "$destination" switch --detach "$ref"
        elif [ "$(git -C "$destination" rev-parse HEAD)" != "$(git -C "$destination" rev-parse --verify "$ref^{commit}" 2>/dev/null || true)" ]; then
            printf '%s needs version %s. Run sh install.sh --update.\n' "$name" "$ref" >&2
            exit 1
        fi
    else
        git clone --depth 1 --branch "$ref" "$repository" "$destination"
    fi
    printf 'Installed %s at %s\n' "$name" "$ref"
}

install_package ramp-starter \
    "${RAMP_STARTER_REPOSITORY:-https://github.com/KristalAlfred/ramp-starter.git}" \
    "${RAMP_STARTER_REF:-v0.1.0}"
install_package ronna \
    "${RONNA_RAMP_REPOSITORY:-https://github.com/KristalAlfred/ronna-ramp.git}" \
    "${RONNA_RAMP_REF:-v0.1.0}"

printf '%s\n' 'Lua packages installed. Start Ramp with: ramp sessions'
