#! /bin/bash

checkRoot() {
    if [ "$(id -u)" -ne 0 ]; then
        printf 'Error: This script must be run as root.\n' >&2
        exit 1
    fi
}

checkTime() {
    [[ $# -ne 0 ]] && { echo "${FUNCNAME[0]} expects 0 arguments" ; exit 1; }
    local dateHeader
    dateHeader=$(curl -sI https://google.com | grep '^date:' | cut -d' ' -f2-)
    
    if [ -z "$dateHeader" ]; then
        printf 'Error: Could not retrieve time and date.\n' >&2
        exit 1
    fi
    
    date -s "$dateHeader"
}

validateInput() {
    [[ $# -ne 2 ]] && { echo "${FUNCNAME[0]} expects 2 arguments" ; exit 1; }
    local argCount="$1"
    local selection="$2"

    if [ "$argCount" -ne 1 ] || [ "$selection" == "--help" ] || [ "$selection" == "-h" ]; then
        printf 'Usage: %s [arch|cinnamon|container|kali|manjaro]\n' "$0" >&2
        exit 0
    fi

    case "$selection" in
        arch|cinnamon|container|kali|manjaro) ;;
        *) printf 'Error: Unsupported option: %s\n' "$selection" >&2
           exit 1
           ;;
    esac
}

setupTrap() {
    onErr() {
        local rc=${?}
        local lineno=${BASH_LINENO[0]:-?}
        trap - ERR

        [[ -d "$mntPoint" ]] && umount -flR "$mntPoint" 2>&1 || true
        udevadm settle
        [[ -d "$mntPoint" ]] && rmdir "$mntPoint" || true
        [[ -n "$loopDev" ]] && losetup -d "$loopDev" 2>/&1 || true
        
        printf 'Error in command: %s\nLine: %s\nExit code: %s\n' "$BASH_COMMAND" "$lineno" "$rc" >&2
        exit "$rc"
    }

    trap 'onErr' ERR
}

distroName() {
    [[ $# -ne 1 ]] && { echo "${FUNCNAME[0]} expects 1 argument" ; exit 1; }
    case "$1" in
        cinnamon) echo "manjaro" ;;
        container) echo "arch";;
        *)        echo "$1" ;;
    esac
}

imageName() {
    [[ $# -ne 1 ]] && { echo "${FUNCNAME[0]} expects 1 argument" ; exit 1; }
    case "$1" in
        cinnamon) echo "manjaro-cinnamon.img" ;;
        *)        echo "$1-minimal.img" ;;
    esac
}

extrasName() {
    [[ $# -ne 1 ]] && { echo "${FUNCNAME[0]} expects 1 argument" ; exit 1; }
    case "$1" in
        cinnamon) echo "cinnamon lightdm lightdm-gtk-greeter xfce4-terminal pamac" ;;
        container) echo "docker docker-compose";;
        *)        echo "" ;;
    esac
}
