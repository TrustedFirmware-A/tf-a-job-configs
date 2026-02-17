#!/usr/bin/env bash
#
# Copyright (c) 2021-2025 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Clones and checkout TF-A related repositories into the current workspace.

set -ex

git config --global --add url."https://review.trustedfirmware.org/mirror/mbed-tls.git".insteadOf "https://github.com/Mbed-TLS/mbedtls.git"
git config --global --add url."https://review.trustedfirmware.org/mirror/mbed-tls.git".insteadOf "https://github.com/ARMmbed/mbedtls.git"

: "${CLONE_REPOS:?}"

# Global defaults
REFSPEC_MASTER="refs/heads/master"
REFSPEC_MAIN="refs/heads/main"
REFSPEC_TF_M_TESTS="refs/heads/tfa_ci_dep_revision"
REFSPEC_TF_M_EXTRAS="refs/heads/tfa_ci_dep_revision"
GIT_REPO="https://git.trustedfirmware.org"
GERRIT_HOST="https://review.trustedfirmware.org"
SSH_PARAMS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PubkeyAcceptedKeyTypes=+ssh-rsa -p 29418 -i ${CI_BOT_KEY}"
GERRIT_QUERY_PARAMS="--format=JSON --patch-sets --current-patch-set status:open"

export GIT_SSH_COMMAND="ssh ${SSH_PARAMS}"

# Defaults Projects
TF_GERRIT_PROJECT="${TF_GERRIT_PROJECT:-${GERRIT_PROJECT_PREFIX}TF-A/trusted-firmware-a}"
TF_M_TESTS_GERRIT_PROJECT="${TF_M_TESTS_GERRIT_PROJECT:-${GERRIT_PROJECT_PREFIX}TF-M/tf-m-tests}"
TF_M_EXTRAS_GERRIT_PROJECT="${TF_M_EXTRAS_GERRIT_PROJECT:-${GERRIT_PROJECT_PREFIX}TF-M/tf-m-extras}"
TFTF_GERRIT_PROJECT="${TFTF_GERRIT_PROJECT:-${GERRIT_PROJECT_PREFIX}TF-A/tf-a-tests}"
SPM_GERRIT_PROJECT="${SPM_GERRIT_PROJECT:-${GERRIT_PROJECT_PREFIX}hafnium/hafnium}"
RMM_GERRIT_PROJECT="${RMM_GERRIT_PROJECT:-${GERRIT_PROJECT_PREFIX}TF-RMM/tf-rmm}"
CI_GERRIT_PROJECT="${CI_GERRIT_PROJECT:-${GERRIT_PROJECT_PREFIX}ci/tf-a-ci-scripts}"
RF_GERRIT_PROJECT="${RF_GERRIT_PROJECT:-${GERRIT_PROJECT_PREFIX}RF-A/rusted-firmware-a}"
ARM_FFA_GERRIT_PROJECT="${ARM_FFA_GERRIT_PROJECT:-${GERRIT_PROJECT_PREFIX}arm-firmware-crates/arm-ffa}"
ARM_PL011_UART_GERRIT_PROJECT="${ARM_PL011_UART_GERRIT_PROJECT:-${GERRIT_PROJECT_PREFIX}arm-firmware-crates/arm-pl011-uart}"
ARM_PSCI_GERRIT_PROJECT="${ARM_PSCI_GERRIT_PROJECT:-${GERRIT_PROJECT_PREFIX}arm-firmware-crates/arm-psci}"
ARM_FVP_BASE_PAC_GERRIT_PROJECT="${ARM_FVP_BASE_PAC_GERRIT_PROJECT:-${GERRIT_PROJECT_PREFIX}arm-firmware-crates/arm-fvp-base-pac}"
ARM_SP805_GERRIT_PROJECT="${ARM_SP805_GERRIT_PROJECT:-${GERRIT_PROJECT_PREFIX}arm-firmware-crates/arm-sp805}"
ARM_XLAT_GERRIT_PROJECT="${ARM_XLAT_GERRIT_PROJECT:-${GERRIT_PROJECT_PREFIX}rust-spmc/arm-xlat}"
ARM_FW_DEV_GUIDE_GERRIT_PROJECT="${ARM_FW_DEV_GUIDE_GERRIT_PROJECT:-${GERRIT_PROJECT_PREFIX}rust-spmc/firmware-development-guide}"
ARM_GENERIC_TIMER_GERRIT_PROJECT="${ARM_GENERIC_TIMER_GERRIT_PROJECT:-${GERRIT_PROJECT_PREFIX}arm-firmware-crates/arm-generic-timer}"
ARM_CCI_GERRIT_PROJECT="${ARM_CCI_GERRIT_PROJECT:-${GERRIT_PROJECT_PREFIX}arm-firmware-crates/arm-cci}"
ARM_GIC_GERRIT_PROJECT="${ARM_GIC_GERRIT_PROJECT:-${GERRIT_PROJECT_PREFIX}arm-firmware-crates/arm-gic}"
ARM_TZC_GERRIT_PROJECT="${ARM_TZC_GERRIT_PROJECT:-${GERRIT_PROJECT_PREFIX}arm-firmware-crates/arm-tzc}"
ARM_PL061_GERRIT_PROJECT="${ARM_PL061_GERRIT_PROJECT:-${GERRIT_PROJECT_PREFIX}arm-firmware-crates/arm-pl061}"
ARM_MHU_GERRIT_PROJECT="${ARM_MHU_GERRIT_PROJECT:-${GERRIT_PROJECT_PREFIX}arm-firmware-crates/arm-mhu}"
ARM_SCMI_GERRIT_PROJECT="${ARM_SCMI_GERRIT_PROJECT:-${GERRIT_PROJECT_PREFIX}arm-firmware-crates/arm-scmi}"
ARM_SYSREGS_GERRIT_PROJECT="${ARM_SYSREGS_GERRIT_PROJECT:-${GERRIT_PROJECT_PREFIX}arm-firmware-crates/arm-sysregs}"
TF_FIRMWARE_HANDOFF_GERRIT_PROJECT="${TF_FIRMWARE_HANDOFF_GERRIT_PROJECT:-${GERRIT_PROJECT_PREFIX}shared/tf-firmware-handoff}"
JOBS_PROJECT="${JOBS_PROJECT:-${GERRIT_PROJECT_PREFIX}ci/tf-a-job-configs.git}"

# Default Reference specs
TF_GERRIT_REFSPEC="${TF_GERRIT_REFSPEC:-${REFSPEC_MASTER}}"
TFTF_GERRIT_REFSPEC="${TFTF_GERRIT_REFSPEC:-${REFSPEC_MASTER}}"
SPM_REFSPEC="${SPM_REFSPEC:-${REFSPEC_MASTER}}"
RMM_REFSPEC="${RMM_REFSPEC:-${REFSPEC_MAIN}}"
TF_M_TESTS_GERRIT_REFSPEC="${TF_M_TESTS_GERRIT_REFSPEC:-${REFSPEC_TF_M_TESTS}}"
TF_M_EXTRAS_GERRIT_REFSPEC="${TF_M_EXTRAS_GERRIT_REFSPEC:-${REFSPEC_TF_M_EXTRAS}}"
CI_REFSPEC="${CI_REFSPEC:-${REFSPEC_MASTER}}"
RFA_REFSPEC="${RFA_REFSPEC:-${REFSPEC_MAIN}}"
ARM_FFA_GERRIT_REFSPEC="${ARM_FFA_GERRIT_REFSPEC:-${REFSPEC_MAIN}}"
ARM_PL011_UART_GERRIT_REFSPEC="${ARM_PL011_UART_GERRIT_REFSPEC:-${REFSPEC_MAIN}}"
ARM_PSCI_GERRIT_REFSPEC="${ARM_PSCI_GERRIT_REFSPEC:-${REFSPEC_MAIN}}"
ARM_FVP_BASE_PAC_GERRIT_REFSPEC="${ARM_FVP_BASE_PAC_GERRIT_REFSPEC:-${REFSPEC_MAIN}}"
ARM_SP805_GERRIT_REFSPEC="${ARM_SP805_GERRIT_REFSPEC:-${REFSPEC_MAIN}}"
ARM_XLAT_GERRIT_REFSPEC="${ARM_XLAT_GERRIT_REFSPEC:-${REFSPEC_MAIN}}"
ARM_FW_DEV_GUIDE_GERRIT_REFSPEC="${ARM_FW_DEV_GUIDE_GERRIT_REFSPEC:-${REFSPEC_MAIN}}"
ARM_GENERIC_TIMER_GERRIT_REFSPEC="${ARM_GENERIC_TIMER_GERRIT_REFSPEC:-${REFSPEC_MAIN}}"
ARM_CCI_GERRIT_REFSPEC="${ARM_CCI_GERRIT_REFSPEC:-${REFSPEC_MAIN}}"
ARM_GIC_GERRIT_REFSPEC="${ARM_GIC_GERRIT_REFSPEC:-${REFSPEC_MAIN}}"
ARM_TZC_GERRIT_REFSPEC="${ARM_TZC_GERRIT_REFSPEC:-${REFSPEC_MAIN}}"
ARM_PL061_GERRIT_REFSPEC="${ARM_PL061_GERRIT_REFSPEC:-${REFSPEC_MAIN}}"
ARM_MHU_GERRIT_REFSPEC="${ARM_MHU_GERRIT_REFSPEC:-${REFSPEC_MAIN}}"
ARM_SCMI_GERRIT_REFSPEC="${ARM_SCMI_GERRIT_REFSPEC:-${REFSPEC_MAIN}}"
ARM_SYSREGS_GERRIT_REFSPEC="${ARM_SYSREGS_GERRIT_REFSPEC:-${REFSPEC_MAIN}}"
TF_FIRMWARE_HANDOFF_GERRIT_REFSPEC="${TF_FIRMWARE_HANDOFF_GERRIT_REFSPEC:-${REFSPEC_MAIN}}"
JOBS_REFSPEC="${JOBS_REFSPEC:-${REFSPEC_MASTER}}"

JOBS_REPO_NAME="tf-a-job-configs"
JOBS_REPO_URL="${GIT_REPO}/${JOBS_PROJECT}"

# Array containing "<repo host>;<project>;<repo name>;<refspec>" elements
declare -A repos_map=(
  ["tf-a-ci-scripts"]="${GERRIT_HOST};${CI_GERRIT_PROJECT};${CI_REFSPEC}"
  ["trusted-firmware-a"]="${GERRIT_HOST};${TF_GERRIT_PROJECT};${TF_GERRIT_REFSPEC}"
  ["tf-a-tests"]="${GERRIT_HOST};${TFTF_GERRIT_PROJECT};${TFTF_GERRIT_REFSPEC}"
  ["spm"]="${GERRIT_HOST};${SPM_GERRIT_PROJECT};${SPM_REFSPEC}"
  ["tf-rmm"]="${GERRIT_HOST};${RMM_GERRIT_PROJECT};${RMM_REFSPEC}"
  ["tf-m-tests"]="${GERRIT_HOST};${TF_M_TESTS_GERRIT_PROJECT};${TF_M_TESTS_GERRIT_REFSPEC}"
  ["tf-m-extras"]="${GERRIT_HOST};${TF_M_EXTRAS_GERRIT_PROJECT};${TF_M_EXTRAS_GERRIT_REFSPEC}"
  ["rusted-firmware-a"]="${GERRIT_HOST};${RF_GERRIT_PROJECT};${RFA_REFSPEC}"
  ["arm-ffa"]="${GERRIT_HOST};${ARM_FFA_GERRIT_PROJECT};${ARM_FFA_GERRIT_REFSPEC}"
  ["arm-pl011-uart"]="${GERRIT_HOST};${ARM_PL011_UART_GERRIT_PROJECT};${ARM_PL011_UART_GERRIT_REFSPEC}"
  ["arm-psci"]="${GERRIT_HOST};${ARM_PSCI_GERRIT_PROJECT};${ARM_PSCI_GERRIT_REFSPEC}"
  ["arm-gic"]="${GERRIT_HOST};${ARM_GIC_GERRIT_PROJECT};${ARM_GIC_GERRIT_REFSPEC}"
  ["arm-fvp-base-pac"]="${GERRIT_HOST};${ARM_FVP_BASE_PAC_GERRIT_PROJECT};${ARM_FVP_BASE_PAC_GERRIT_REFSPEC}"
  ["arm-sp805"]="${GERRIT_HOST};${ARM_SP805_GERRIT_PROJECT};${ARM_SP805_GERRIT_REFSPEC}"
  ["arm-xlat"]="${GERRIT_HOST};${ARM_XLAT_GERRIT_PROJECT};${ARM_XLAT_GERRIT_REFSPEC}"
  ["arm-generic-timer"]="${GERRIT_HOST};${ARM_GENERIC_TIMER_GERRIT_PROJECT};${ARM_GENERIC_TIMER_GERRIT_REFSPEC}"
  ["arm-cci"]="${GERRIT_HOST};${ARM_CCI_GERRIT_PROJECT};${ARM_CCI_GERRIT_REFSPEC}"
  ["arm-tzc"]="${GERRIT_HOST};${ARM_TZC_GERRIT_PROJECT};${ARM_TZC_GERRIT_REFSPEC}"
  ["arm-pl061"]="${GERRIT_HOST};${ARM_PL061_GERRIT_PROJECT};${ARM_PL061_GERRIT_REFSPEC}"
  ["arm-mhu"]="${GERRIT_HOST};${ARM_MHU_GERRIT_PROJECT};${ARM_MHU_GERRIT_REFSPEC}"
  ["arm-scmi"]="${GERRIT_HOST};${ARM_SCMI_GERRIT_PROJECT};${ARM_SCMI_GERRIT_REFSPEC}"
  ["arm-sysregs"]="${GERRIT_HOST};${ARM_SYSREGS_GERRIT_PROJECT};${ARM_SYSREGS_GERRIT_REFSPEC}"
  ["tf-firmware-handoff"]="${GERRIT_HOST};${TF_FIRMWARE_HANDOFF_GERRIT_PROJECT};${TF_FIRMWARE_HANDOFF_GERRIT_REFSPEC}"
  ["firmware-development-guide"]="${GERRIT_HOST};${ARM_FW_DEV_GUIDE_GERRIT_PROJECT};${ARM_FW_DEV_GUIDE_GERRIT_REFSPEC}"
)


test_desc="${test_desc:-$TEST_DESC}"
if [ -n "${test_desc}" ]; then
    build_config="$(echo "${test_desc%%:*}" | cut -d'%' -f3)"
    # Read config fields into array safely
    IFS=',' read -ra config_fields <<< "$build_config"

    declare -A build_configs=(
        ["trusted-firmware-a"]="${config_fields[0]}"
        ["tf-a-tests"]="${config_fields[1]}"
        ["spm"]="${config_fields[2]}"
        ["tf-rmm"]="${config_fields[3]}"
    )
fi

df -h

# Clone JOBS_PROJECT first, since we need a helper script there
git init --quiet -- "${JOBS_REPO_NAME}"
git -C "${JOBS_REPO_NAME}" remote add origin "${JOBS_REPO_URL}"
git -C "${JOBS_REPO_NAME}" fetch --quiet --depth 1 --no-tags \
    --no-recurse-submodules -- origin "${JOBS_REFSPEC}"
git -C "${JOBS_REPO_NAME}" checkout --quiet --detach FETCH_HEAD
git -C "${JOBS_REPO_NAME}" submodule update --quiet --depth 1 --init \
    --recursive

git -C ${JOBS_REPO_NAME} log -1

# clone git repos
for repo in ${!repos_map[@]}; do
    if [[ -v build_configs["$repo"] ]]; then
        val="${build_configs[$repo]}"
        if [[ -z "$val" || "$val" == *"nil"* ]]; then
            continue
        fi
    fi

    # parse the repo elements
    IFS=';' read -r REPO_HOST REPO_PROJECT REPO_DEFAULT_REFSPEC <<< "${repos_map[${repo}]}"

    REPO_NAME="$repo"
    REPO_URL="${REPO_HOST}/${REPO_PROJECT}"
    REPO_REFSPEC="${REPO_DEFAULT_REFSPEC}"
    # if a list of repos is provided via the CLONE_REPOS build param, only clone
    # those in the list - otherwise all are cloned by default
    if [[ -n "${CLONE_REPOS}" ]] && ! grep -qw "${REPO_NAME}" <<< "${CLONE_REPOS}"; then
        continue
    fi

    # If the Gerrit review that triggered the CI had a topic, it will be used to synchronize the other repositories
    if [ -n "${GERRIT_TOPIC}" -a "${REPO_HOST}" = "${GERRIT_HOST}" -a "${GERRIT_PROJECT}" != "${REPO_PROJECT}" ]; then
        echo "Got Gerrit Topic: ${GERRIT_TOPIC}"
        REPO_REFSPEC="$(ssh ${SSH_PARAMS} ${CI_BOT_USERNAME}@${REPO_HOST#https://} gerrit query ${GERRIT_QUERY_PARAMS} \
                        project:${REPO_PROJECT} topic:${GERRIT_TOPIC} | ${JOBS_REPO_NAME}/scripts/parse_refspec.py)"
        if [ -z "${REPO_REFSPEC}" ]; then
            REPO_REFSPEC="${REPO_DEFAULT_REFSPEC}"
            echo "Roll back to \"${REPO_REFSPEC}\" for \"${REPO_PROJECT}\""
        fi
        echo "Checkout refspec \"${REPO_REFSPEC}\" from repository \"${REPO_NAME}\""
    fi

    git init --quiet -- "${REPO_NAME}"
    git -C "${REPO_NAME}" remote add origin "${REPO_URL}"
    git -C "${REPO_NAME}" fetch --quiet --depth 1 --no-tags \
        --no-recurse-submodules -- origin "${REPO_REFSPEC}"
    git -C "${REPO_NAME}" checkout --quiet --detach FETCH_HEAD
    git -C "${REPO_NAME}" submodule update --quiet --depth 1 --init \
        --recursive

    echo "Freshly cloned ${REPO_URL} (refspec ${REPO_REFSPEC}):"

    git -C ${REPO_NAME} log -1
done
