#!/bin/bash

source "./libScript.sh"
source "./libVolume.sh"
source "./libPrepareDistro.sh"
source "./libInstallDistro.sh"
source "./libPatchDistro.sh"

set -Eo pipefail
setupTrap
checkRoot
checkTime
validateInput "$#" "$1"

inputArg="$1"
distro=$(distroName "$inputArg")
extras=$(extrasName "$inputArg")
imgFile=$(imageName "$inputArg")
imgSize="6G"

loopDev=""
mntPoint=""

setupVolume "$imgFile" "$imgSize"
mountVolume "$loopDev"

prepareDistro "$mntPoint" "$distro" "$extras"
installDistro "$mntPoint" "$distro"

patchOEM "$mntPoint" "$distro"
patchRosetta "$mntPoint"
patchDistro "$mntPoint" "$inputArg"
cleanupSystem "$mntPoint" "$distro"

umountVolume "$loopDev" "$mntPoint"
compressImage "$imgFile"
