#!/bin/bash
#
set -ex

TO_BUILD_FILE="${WORKSPACE}/TO_BUILD"
JOB_URL=${JOB_URL//http:/https:}
last_build=$((${BUILD_NUMBER}-1))
API_URL="${JOB_URL}/${last_build}/api/json"
if [ ${last_build} -eq 0 ]; then
    echo "This is the first build"
    touch ${TO_BUILD_FILE}
else
    repos_to_check="trusted-firmware-a tf-a-tests tf-a-ci-scripts"
    last_build=$(curl -sL ${API_URL})
    last_build_ts=$(echo ${last_build} | jq '.timestamp')
    last_build_ts=$((${last_build_ts}/1000))
    last_build_result=$(echo ${last_build} | jq -r '.result')

    if [ "${FORCE_TO_BUILD}" = "true" -o "${last_build_result}" != "SUCCESS" ]; then
        touch ${TO_BUILD_FILE}
    else
        for r in ${repos_to_check}
        do
            last_commit_ts=$(git -C ${r} show --no-patch --format=%ct)
            # if the last commit was not covered by the last build
            # the new build will be proceeded
            if [ ${last_commit_ts} -ge ${last_build_ts} ]; then
                touch ${TO_BUILD_FILE}
                break
            fi
        done
    fi
fi
