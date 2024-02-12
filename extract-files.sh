#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2023 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

ONLY_COMMON=
ONLY_TARGET=
KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        --only-common )
                ONLY_COMMON=true
                ;;
        --only-target )
                ONLY_TARGET=true
                ;;
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup() {
    case "${1}" in
        vendor/etc/msm_irqbalance.conf)
            sed -i "s/IGNORED_IRQ=27,23,38$/&,115,332/" "${2}"
            ;;
        vendor/etc/media_lahaina/video_system_specs.json \
        |vendor/etc/media_shima_v1/video_system_specs.json \
        |vendor/etc/media_yupik_v1/video_system_specs.json)
            sed -i "/max_retry_alloc_output_timeout/ s/10000/0/" "${2}"
            ;;
        vendor/etc/vintf/manifest/c2_manifest_vendor.xml)
            sed -ni '/ozoaudio/!p' "${2}"
            ;;
        vendor/lib/libcodec2_hidl@1.0.stock.so)
            patchelf --set-soname libcodec2_hidl@1.0.stock.so "${2}"
            patchelf --replace-needed libcodec2_vndk.so libcodec2_vndk.stock.so "${2}"
            ;;
        vendor/lib/libcodec2_vndk.stock.so)
            patchelf --set-soname libcodec2_vndk.stock.so "${2}"
            ;;
        vendor/lib64/c2.dolby.avc.dec.so | vendor/lib64/c2.dolby.avc.sec.dec.so | vendor/lib64/c2.dolby.egl.so | vendor/lib64/c2.dolby.hevc.dec.so | vendor/lib64/c2.dolby.hevc.enc.so | vendor/lib64/c2.dolby.hevc.sec.dec.so | vendor/lib64/libdolbyvision.so | vendor/lib/libcodec2_soft_common.so | vendor/lib/libsfplugin_ccodec_utils.so)
            grep -q "libstagefright_foundation-v33.so" "${2}" || "${PATCHELF}" --replace-needed "libstagefright_foundation.so" "libstagefright_foundation-v33.so" "${2}"
            ;;
        vendor/lib/libstagefright_soft_ac4dec.so | vendor/lib/libstagefright_soft_ddpdec.so | vendor/lib/libstagefrightdolby.so | vendor/lib64/libdlbdsservice.so | vendor/lib64/libstagefright_soft_ac4dec.so | vendor/lib64/libstagefright_soft_ddpdec.so | vendor/lib64/libstagefrightdolby.so)
            grep -q "libstagefright_foundation-v33.so" "${2}" || "${PATCHELF}" --replace-needed "libstagefright_foundation.so" "libstagefright_foundation-v33.so" "${2}"
            ;;
        vendor/lib64/android.hardware.secure_element@1.0-impl.so)
            "${PATCHELF}" --remove-needed "android.hidl.base@1.0.so" "${2}"
            ;;
    esac
}

if [ -z "${ONLY_TARGET}" ]; then
    # Initialize the helper for common device
    setup_vendor "${DEVICE_COMMON}" "${VENDOR}" "${ANDROID_ROOT}" true "${CLEAN_VENDOR}"

    extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"
fi

if [ -z "${ONLY_COMMON}" ] && [ -s "${MY_DIR}/../${DEVICE}/proprietary-files.txt" ]; then
    # Reinitialize the helper for device
    source "${MY_DIR}/../${DEVICE}/extract-files.sh"
    setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

    extract "${MY_DIR}/../${DEVICE}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"

    if [ -f "${MY_DIR}/../${DEVICE}/proprietary-firmware.txt" ]; then
        extract_firmware "${MY_DIR}/../${DEVICE}/proprietary-firmware.txt" "${SRC}"
    fi
fi

"${MY_DIR}/setup-makefiles.sh"
