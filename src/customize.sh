#!/usr/bin/env bash
#
# Copyright (C) 2025 ぼっち <ayumi.aiko@outlook.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# SOURCE THIS TO GET HEX CODES!!!!!
source ./patches.conf || . ./patches.conf

# FUNCTIONS!!!!
function magiskboot() {
    local localMachineArchitecture=$(uname -m)
    local binaryPath="../bin/"
    # mb path could change so sybau terminal
    if [ ! -f "${binaryPath}/magiskbootX32" ]; then
        binaryPath="../../bin/"
        if [ ! -f "${binaryPath}/magiskbootX32" ]; then
            binaryPath=""
        fi
    fi
    case "${localMachineArchitecture}" in 
        "i686")
            ${binaryPath}magiskbootX32 "$@"
        ;;
        "x86_64")
            ${binaryPath}magiskbootX64 "$@"
        ;;
        "armv7l")
            ${binaryPath}magiskbootA32 "$@"
        ;;
        "aarch64"|"armv8l")
            ${binaryPath}magiskbootA64 "$@"
        ;;
        *)
            abort "Undefined architecture ${localMachineArchitecture}"
        ;;
    esac
}

function abort() {
    echo "$@"
    exit 1
}

function applyHexPatches() {
    local binary_file="$1"
    local patches_applied=0
    local total_patches=${#HEX_PATCHES[@]}    
    # Temporarily disable exit on error for individual patch attempts
    echo "Trying to apply hex patches to ${binary_file}..."
    set +e
    # Split the patch string into search and replace patterns
    for patch in "${HEX_PATCHES[@]}"; do
        local search_pattern="${patch%%:*}"
        local replace_pattern="${patch##*:}"

        # Apply the patch and capture the exit code
        if magiskboot hexpatch "${binary_file}" "${search_pattern}" "${replace_pattern}"; then
            ((patches_applied++))
            #else: echo "Failed to apply patch: ${search_pattern} -> ${replace_pattern}\n" "applyHexPatches"
        fi
    done
    # Re-enable exit on error
    set -e
    echo "Applied ${patches_applied}/${total_patches} patches\n"
    # Return success if at least one patch was applied
    [ $patches_applied -gt 0 ]
}
# FUNCTIONS!!!!

# elite ball knowledge. I dont usually put comments but i thought i think i REALLY need to do that here.
# variables:
export expectedRecoveryFilePath="$(realpath ./recovery.img)"
export patchedRecoveryFilePath="$(realpath ./patched-recovery.img)"

# main:
echo "PatchRecoveryRevived"
echo "Made by: Ravindu Deshan and simplyfied by ぼっち"
echo "Based on: v3.0"
echo "License Template: GNU GPLv3"
echo "Trying to unpack the recovery image.."

# ask user for the recovery image path if not set
if [ -z "${expectedRecoveryFilePath}" ]; then
    printf "Enter the path to the recovery image: "
    read pathToSahur
    [ -z "${pathToSahur}" ] && abort "You were supposed to enter a path. Exiting.."
    expectedRecoveryFilePath="$(realpath "${pathToSahur}")"
    unset pathToSahur
    # check if the expected file is available or not.
    [ -f "${expectedRecoveryFilePath}" ] && echo "Recovery image found at: ${expectedRecoveryFilePath}" || \
        abort "Expected recovery image not found at: ${expectedRecoveryFilePath}"
fi

# we need a temporary working dir and we need to switch it to the module directory AFTER running inside "scope"
# firstScope:
{
    rm -rf "./base" &>/dev/null || mkdir -p ./base
    cd ./base
    magiskboot unpack -h ${expectedRecoveryFilePath} &>/dev/null || abort "Failed to unpack the recovery image, please try again with a supported recovery image."
    [ ! -f "ramdisk.cpio" ] && abort "Cannot find ramdisk.cpio in the unpacked recovery image. This recovery image may not be compatible with this script."
    # verify if the files are present or not in the ramdisk before being a moron and fucking the recovery image up.
    magiskboot cpio "./ramdisk.cpio" "exists system/bin/recovery" || 
    abort "The \'recovery\' binary was not present in the ramdisk from the recovery? weird image, try again with an actual image."
    magiskboot cpio "./ramdisk.cpio" "exists system/bin/fastbootd" || abort "This recovery image doesn't natively have fastboot binaries, please try again with a supported recovery image."    
    # now extract it and be a bitch
    echo "Trying to extract the recovery binary file from the ramdisk.."
    magiskboot cpio "./ramdisk.cpio" "extract system/bin/recovery" && echo "Successfully extracted the recovery & fastbootd binaries from the recovery ramdisk." || \
        abort "Failed to extract the recovery binary from the ramdisk, please try again."
    applyHexPatches "./system/bin/recovery"
    magiskboot cpio ./ramdisk.cpio "add 0755 system/bin/recovery ./recovery" &>/dev/null || abort "Failed to add the patched recovery binary into the recovery image, please try again."
    magiskboot repack "${expectedRecoveryFilePath}" "${patchedRecoveryFilePath}" &>/dev/null || abort "Failed to repack the recovery image, please try again."
    echo "Successfully repacked the recovery image with the patched recovery binary."
    echo "The patched recovery image is available at: ${patchedRecoveryFilePath}"
}

# out:
if ask "Do you want to get a compressed tar for the patched recovery file?"; then
    lz4 -B6 --content-size ${patchedRecoveryFilePath} ${patchedRecoveryFilePath}.lz4 && rm ${patchedRecoveryFilePath} &>/dev/null || \
        abort "Failed to compress the patched recovery image, please try again."
    echo "Successfully compressed the patched recovery image to: ${patchedRecoveryFilePath}.lz4"
    # create a tar file
    tar -cvf "Fastbootd-patched-recovery.tar" ${patchedRecoveryFilePath}.lz4 && rm ${patchedRecoveryFilePath}.lz4 &>/dev/null || \
        abort "Failed to create a tar file for the patched recovery image, please try again."
    echo "Created Fastbootd-patched-recovery.tar in the ${patchedRecoveryFilePath}"
fi