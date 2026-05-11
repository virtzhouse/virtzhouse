#!/bin/bash

setupVolume() {
    [[ $# -ne 2 ]] && { echo "${FUNCNAME[0]} expects 2 arguments" ; exit 1; }
    local imgFile="$1"
    local imgSize="$2"

    losetup -D
    rm -f "$imgFile"
    truncate -s "$imgSize" "$imgFile"
    loopDev=$(losetup -fP --show "$imgFile")
    
    parted "$loopDev" mklabel gpt
    parted "$loopDev" mkpart primary fat32 1MiB 1025MiB
    parted "$loopDev" mkpart primary ext4 1025MiB 100%
    parted "$loopDev" set 1 boot on
    parted "$loopDev" set 1 esp on
    
    mkfs.vfat -F32 "${loopDev}p1"
    mkfs.ext4 "${loopDev}p2"
    
    udevadm settle
}

mountVolume() {
    [[ $# -ne 1 ]] && { echo "${FUNCNAME[0]} expects 1 argument" ; exit 1; }
    local loopDev="$1"
    
    mntPoint=$(mktemp -d -t mnt.XXXXXXX)
    
    mount -n "${loopDev}p2" "$mntPoint"
    mkdir -p "$mntPoint/boot"
    mount -n "${loopDev}p1" "$mntPoint/boot"
}

umountVolume() {
    [[ $# -ne 2 ]] && { echo "${FUNCNAME[0]} expects 2 arguments" ; exit 1; }
    local loopDev="$1"
    local mntPoint="$2"
    
    umount -flR "$mntPoint" 2>&1 || true
    udevadm settle
    rmdir "$mntPoint"
    losetup -d "$loopDev" 2>&1 || true
}

compressImage() {
    [[ $# -ne 1 ]] && { echo "${FUNCNAME[0]} expects 1 argument" ; exit 1; }
    local imgFile="$1"
    
    xz -vkc --format=lzma -9e "$imgFile" > "$imgFile.lzma"
}
