#!/usr/bin/env bash
#
# Copyright (c) 2021-2023 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Clones and checkout TF-A related repositories in case these are not present
# under SHARE_FOLDER, otherwise copy the share repositories into current folder
# (workspace)

# The way it works is simple: the top level job sets the SHARE_FOLDER
# parameter based on its name and number on top of the share
# volume (/srv/shared/<job name>/<job number>) then it calls the clone
# script (clone.sh), which in turn it fetches the repositories mentioned
# above. Jobs triggered on behalf of the latter, share the same
# SHARE_FOLDER value, and these in turn also call the clone script, but
# in this case, the script detects that the folder is already populated so
# its role is to simply copy the repositories into the job's
# workspace. As seen, all jobs work with repositories on their own
# workspace, which are just copies of the share folder, so there is no
# change of a race condition, i.e every job works with its own copy. The
# worst case scenario is where the down-level job, tf-a-builder, uses its
# default SHARE_FOLDER value, in this case, it would simply clone its
# own repositories without reusing any file however the current approach
# prevents the latter unless the job is triggered manually from the
# builder job itself.

set -ex

# Global defaults
CLONE_REPOS=${CLONE_REPOS:-trusted-firmware-a,tf-a-ci-scripts,tf-a-tests,tf-m-extras,tf-m-tests,tf-rmm,spm}
REFSPEC_MASTER="refs/heads/master"
REFSPEC_MAIN="refs/heads/main"
REFSPEC_TF_M_TESTS="refs/heads/tfa_ci_dep_revision"
REFSPEC_TF_M_EXTRAS="refs/heads/tfa_ci_dep_revision"
GIT_REPO="https://git.trustedfirmware.org"
GERRIT_HOST="https://review.trustedfirmware.org"
GIT_CLONE_PARAMS=""
SSH_PARAMS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PubkeyAcceptedKeyTypes=+ssh-rsa -p 29418 -i ${CI_BOT_KEY}"
GERRIT_QUERY_PARAMS="--format=JSON --patch-sets --current-patch-set status:open"

# Defaults Projects
TF_GERRIT_PROJECT="${TF_GERRIT_PROJECT:-TF-A/trusted-firmware-a}"
TF_M_TESTS_GERRIT_PROJECT="${TF_M_TESTS_GERRIT_PROJECT:-TF-M/tf-m-tests}"
TF_M_EXTRAS_GERRIT_PROJECT="${TF_M_EXTRAS_GERRIT_PROJECT:-TF-M/tf-m-extras}"
TFTF_GERRIT_PROJECT="${TFTF_GERRIT_PROJECT:-TF-A/tf-a-tests}"
SPM_GERRIT_PROJECT="${SPM_GERRIT_PROJECT:-hafnium/hafnium}"
RMM_GERRIT_PROJECT="${RMM_GERRIT_PROJECT:-TF-RMM/tf-rmm}"
CI_GERRIT_PROJECT="${CI_GERRIT_PROJECT:-ci/tf-a-ci-scripts}"
RF_GERRIT_PROJECT="${RF_GERRIT_PROJECT:-RF-A/rusted-firmware-a}"
ARM_FFA_GERRIT_PROJECT="${ARM_FFA_GERRIT_PROJECT:-rust-spmc/arm-ffa}"
ARM_PL011_UART_GERRIT_PROJECT="${ARM_PL011_UART_GERRIT_PROJECT:-rust-spmc/arm-pl011-uart}"
ARM_PSCI_GERRIT_PROJECT="${ARM_PSCI_GERRIT_PROJECT:-rust-spmc/arm-psci}"
ARM_FVP_BASE_PAC_GERRIT_PROJECT="${ARM_FVP_BASE_PAC_GERRIT_PROJECT:-rust-spmc/arm-fvp-base-pac}"
ARM_SP805_GERRIT_PROJECT="${ARM_SP805_GERRIT_PROJECT:-rust-spmc/arm-sp805}"
ARM_XLAT_GERRIT_PROJECT="${ARM_XLAT_GERRIT_PROJECT:-rust-spmc/arm-xlat}"
ARM_FW_DEV_GUIDE_GERRIT_PROJECT="${ARM_FW_DEV_GUIDE_GERRIT_PROJECT:-rust-spmc/firmware-development-guide}"
JOBS_PROJECT="${JOBS_PROJECT:-ci/tf-a-job-configs.git}"

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
JOBS_REFSPEC="${JOBS_REFSPEC:-${REFSPEC_MASTER}}"

JOBS_REPO_NAME="tf-a-job-configs"

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
  ["firmware-development-guide"]="${GERRIT_HOST};${ARM_FW_DEV_GUIDE_GERRIT_PROJECT};${ARM_FW_DEV_GUIDE_REFSPEC}"
)


test_desc="${test_desc:-$TEST_DESC}"
if [ -n "${test_desc}" ]; then
    build_config="$(echo "${test_desc%%:*}" | cut -d'%' -f3)"
    # Read config fields into array safely
    IFS=',' read -ra config_fields <<< "$build_config"

    declare -A build_configs=(
        ["trusted-firmware-a"]="${config_fields[0]}"
        ["tf-a-tests"]="${config_fields[1]}"
        ["spm"]="${config_fields[4]}"
        ["tf-rmm"]="${config_fields[5]}"
    )
fi

df -h

# Take into consideration non-CI runs where SHARE_FOLDER variable
# may not be present
if [ -z "${SHARE_FOLDER}" ]; then
    # Default Jenkins values
    SHARE_VOLUME="${SHARE_VOLUME:-$PWD}"
    JOB_NAME="${JOB_NAME:-local}"
    BUILD_NUMBER="${BUILD_NUMBER:-0}"
    SHARE_FOLDER=${SHARE_VOLUME}/${JOB_NAME}/${BUILD_NUMBER}
fi

mkdir -p ${SHARE_FOLDER}

# Clone JOBS_PROJECT first, since we need a helper script there
if [ -f ${SHARE_FOLDER}/${JOBS_REPO_NAME}.tar.gz ]; then
    tar -xzf ${SHARE_FOLDER}/${JOBS_REPO_NAME}.tar.gz
else
    git clone ${GIT_CLONE_PARAMS} ${GIT_REPO}/${JOBS_PROJECT} ${JOBS_REPO_NAME}
    git -C ${JOBS_REPO_NAME} fetch origin ${JOBS_REFSPEC}
    git -C ${JOBS_REPO_NAME} checkout FETCH_HEAD

    tar -czf ${SHARE_FOLDER}/${JOBS_REPO_NAME}.tar.gz ${JOBS_REPO_NAME}
fi

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
    REPO_SSH_URL="ssh://${CI_BOT_USERNAME}@${REPO_HOST#https://}:29418/${REPO_PROJECT}"

    # if a list of repos is provided via the CLONE_REPOS build param, only clone
    # those in the list - otherwise all are cloned by default
    if [[ -n "${CLONE_REPOS}" ]] && ! grep -qw "${REPO_NAME}" <<< "${CLONE_REPOS}"; then
        continue
    fi

    if [ -f ${SHARE_FOLDER}/${REPO_NAME}.tar.gz ]; then
        echo "Using existing shared folder checkout for ${REPO_URL}:"

        tar -xzf ${SHARE_FOLDER}/${REPO_NAME}.tar.gz
    else
        if [[ ${FETCH_SSH} ]]; then
            GIT_SSH_COMMAND="ssh ${SSH_PARAMS}" git clone ${GIT_CLONE_PARAMS} ${REPO_SSH_URL} ${REPO_NAME} \
                    --depth 1 --recurse-submodules --shallow-submodules
        else
            git clone ${GIT_CLONE_PARAMS} ${REPO_URL} ${REPO_NAME} \
                    --depth 1 --recurse-submodules --shallow-submodules
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

        # fetch and checkout the corresponding refspec
        if [[ ${FETCH_SSH} ]]; then
            GIT_SSH_COMMAND="ssh ${SSH_PARAMS}" git -C ${REPO_NAME} fetch ${REPO_SSH_URL} ${REPO_REFSPEC}
        else
            git -C ${REPO_NAME} fetch --depth 1 ${REPO_URL} ${REPO_REFSPEC}
        fi

        git -C ${REPO_NAME} checkout FETCH_HEAD
        git -C ${REPO_NAME} submodule update --init --recursive
        echo "Freshly cloned ${REPO_URL} (refspec ${REPO_REFSPEC}):"

        tar -czf ${SHARE_FOLDER}/${REPO_NAME}.tar.gz ${REPO_NAME}
    fi

    git -C ${REPO_NAME} log -1
done
