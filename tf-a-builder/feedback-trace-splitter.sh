#!/usr/bin/env bash
#
# Copyright (c) 2021 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Takes as input the feedback.log, produced previously `log-splitter.py` script and creates
# several files, including a configuration file (config_file.json) and one more traces files, i.e.
# covtrace-FVP_Base_RevC_2xAEMvA.cluster0.cpu0.log, covtrace-FVP_Base_RevC_2xAEMvA.cluster0.cpu1.log,
# etc. The output files are used by reporting tools (https://gitlab.arm.com/tooling/qa-tools/-/tree/master/coverage-tool) to produce coverage html reports
#
# Parameters:
#   1. Full path folder name where the project resides, i.e. path to trusted-firmware-a
#   2. Full path folder where the traces reside
#   3. Full path folder where ELFs reside
#   4. The corresponding git-refspec for the commit being traced

set -x

FEEDBACK=lava-common.log
COVTRACE=covtrace.log
COVPREFIX=covtrace-
CONFIG_JSON=config_file.json
OUTPUT_JSON=output_file.json

# Variables aware of environment variables
PROJECT_ROOT="${1:-${PWD}}"
TRACES_DIR="${2:-${PWD}}"
TF_GERRIT_REFSPEC="${3:-}"
ARTEFACTS=${WORKSPACE}/artefacts
ELF_ARTIFACTS_DIR="${ARTEFACTS}/debug"

# check if LAVA feedback.log exists, if not, just quit
if [ ! -f ${FEEDBACK} ]; then
    echo ${FEEDBACK} file not found
    exit 0
fi

# From the feedback log, take only the trace data
grep -a ^${COVPREFIX} ${FEEDBACK} > ${COVTRACE}

# Check if there are traces
if [ -n "$(find ${COVTRACE} -empty)" ]; then
    echo no code coverage traces found
    exit 0
fi

# List the elf files
find ${ELF_ARTIFACTS_DIR} -maxdepth 1 -name '*.elf' > elfs.txt
echo "Elfs found:"
cat elfs.txt
case "$TEST_CONFIG" in

    fvp-spm*)
      grep -w "bl1\|bl2\|bl31\|secure_hafnium" elfs.txt > tf-a-elfs.txt
      temp_sources=$(cat <<-END
                {
                "type": "git",
                "URL":  "https://review.trustedfirmware.org/TF-A/trusted-firmware-a",
                "COMMIT": "",
                "REFSPEC": "${TF_GERRIT_REFSPEC}",
                "LOCATION": "trusted-firmware-a"
                },
                {
                "type": "git",
                "URL":  "https://review.trustedfirmware.org/hafnium/hafnium",
                "COMMIT": "",
                "REFSPEC": "${SPM_REFSPEC}",
                "LOCATION": "spm"
                }
END
      )
      ;;
    *) 
      grep -w "bl1\|bl2\|bl31" elfs.txt > tf-a-elfs.txt
      temp_sources=$(cat <<-END
                {
                "type": "git",
                "URL":  "https://review.trustedfirmware.org/TF-A/trusted-firmware-a",
                "COMMIT": "",
                "REFSPEC": "${TF_GERRIT_REFSPEC}",
                "LOCATION": "trusted-firmware-a"
                }
END
      )
      ;;
esac

# Generate config json file required for coverage reporting tools
# source "${WORKSPACE}/repos.sh" # Get repos information
_sources=""
for repo_name in ${repos_array[@]}; do
  _sources=$(cat <<-END
  ${_sources}
  {
  "type": "git",
  "URL":  "$(echo "${repos_array[repo_name]}" | awk -F ';' '{print $1}')",
  "COMMIT": "$(echo "${repos_array[repo_name]}" | awk -F ';' '{print $3}')",
  "REFSPEC": "$(echo "${repos_array[repo_name]}" | awk -F ';' '{print $2}')",
  "LOCATION": "${repo_name}"
},
END

)
done
cat > ${CONFIG_JSON} <<EOF
{
    "configuration":
        {
        "remove_workspace": false,
        "include_assembly": true
        },
    "parameters":
        {
        "objdump": "aarch64-none-elf-objdump",
        "readelf": "aarch64-none-elf-readelf",
        "sources": [
${_sources}
${temp_sources}
                ],
        "workspace": "${PROJECT_ROOT}",
        "output_file": "${OUTPUT_JSON}"
        },
    "elfs": [
EOF

# Split COVTRACE into different files
for trace_file in $(awk '{print $1}' ${COVTRACE} | uniq); do

    # split & remove trace filename in log
    grep -a ^${trace_file} ${COVTRACE} > ${trace_file}
    sed -i "s;${trace_file} ;;g" ${trace_file}
done

elfs=($(cat tf-a-elfs.txt))
declare -p elfs
# Populate elfs config elements
for elf in ${elfs[@]::${#elfs[@]}-1}; do
    # fill the 'elfs' elements
    cat >> ${CONFIG_JSON} <<EOF
             {
             "name": "${elf}",
             "traces": [ "${TRACES_DIR}/${COVPREFIX}*" ]
             },
EOF
done

# print last elf and close main json body
cat >> ${CONFIG_JSON} <<EOF
             {
             "name": "${elfs[-1]}",
             "traces": [ "${TRACES_DIR}/${COVPREFIX}*" ]
             }
            ]
}
EOF
