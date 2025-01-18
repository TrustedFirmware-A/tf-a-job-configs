#!/bin/bash
#
set -ex

last_build=$((${BUILD_NUMBER}-1))
JOB_URL=${JOB_URL//http:/https:}
API_URL="${JOB_URL}/${last_build}/api/json"

TO_BUILD_FILE="${WORKSPACE}/TO_BUILD"
repos_to_check="trusted-firmware-a tf-a-tests tf-a-ci-scripts"
last_build=$(curl -s ${API_URL})
last_build_ts=$(echo ${last_build} | jq '.timestamp')
last_build_ts=$((${last_build_ts}/1000))
last_build_result=$(echo ${last_build} | jq -r '.result')

if [ "${FORCE_TO_BUILD}" = "true" -o "${last_build_result}" = "FAILURE" ]; then
    touch ${TO_BUILD_FILE}
else
    for r in ${repos_to_check}
    do
        pushd ${SHARE_FOLDER}/${r}
        last_commit_ts=$(git show --no-patch --format=%ct)
        # if the last commit was not covered by the last build
        # the new build will be proceeded
        if [ ${last_commit_ts} -ge ${last_build_ts} ]; then
            touch ${TO_BUILD_FILE}
            break
        fi
        popd
    done
fi

