#!/bin/bash

set -xe

USE_SQUAD=0
USE_TUXSUITE_FVP=${USE_TUXSUITE_FVP:-0}

# Get LAVA device type from a job file
get_lava_device_type() {
    local job_file=$1
    awk '/^device_type:/ {print $2}' ${job_file}
}

setup_tuxsuite() {
    mkdir -p ~/.config/tuxsuite/
    cat > ~/.config/tuxsuite/config.ini <<EOF
[default]
token=$TUXSUITE_TOKEN
group=tfc
project=ci
EOF
}

# Wait for the LAVA job to finished
# By default, timeout at 5400 secs (1.5 hours) and monitor every 60 seconds
wait_lava_job() {
    set +x
    local id=$1
    local timeout="${2:-5400}"
    local interval="${3:-60}"

    (( t = timeout ))

    while ((t > 0)); do
        sleep $interval
        resilient_cmd lavacli jobs show $id | tee "${WORKSPACE}/lava-progress.show" | grep 'state *:'
        set +x
        if grep 'state.*: Finished' "${WORKSPACE}/lava-progress.show"; then
            set -x
            cat "${WORKSPACE}/lava-progress.show"
            # finished
            return 0
        fi
        ((t -= interval))
    done
    set -x
    cat "${WORKSPACE}/lava-progress.show"
    echo "Timeout waiting for job to finish"
    # timeout
    return 1
}

# Run the given command passed through parameters, if fails, try
# at most more N-times with a pause of M-seconds until success.
resilient_cmd() {
    set +x
    local max_retries=10
    local sleep_body=2
    local iter=0

    while true; do
        if "$@"; then
            break
        fi

        sleep ${sleep_body}
        # Exponential backoff
        sleep_body=$(( sleep_body * 2 ))
        if [ ${sleep_body} -ge 60 ]; then
            sleep_body=60
            echo "WARNING: Command '$@' still not successful on retry #${iter}, exp backoff already limited" 1>&2
        fi

        iter=$(( iter + 1 ))
        if [ ${iter} -ge ${max_retries} ]; then
            echo "ERROR: Command '$@' failed ${iter} times in row" 1>&2
            set -x
            return 1
        fi
    done
    set -x
    return 0
}

ls -l ${WORKSPACE}

DEVICE=$(get_lava_device_type artefacts-lava/job.yaml)

if [ "${DEVICE}" == "fvp" -a "${USE_TUXSUITE_FVP}" -ne 0 ]; then
    setup_tuxsuite
    set -o pipefail
    for i in $(seq 1 ${LAVA_RETRIES:-3}); do
        echo "# TuxSuite submission iteration #$i"
        if python3 -u -m tuxsuite test submit --device fvp-lava --job-definition artefacts-lava/job.yaml | tee tuxsuite-submit.out; then
            status=0
            break
        else
            status=$?
            echo "TuxSuite test failed, status: ${status}"
        fi
    done
    TUXID=$(awk '/^uid:/ {print $2}' tuxsuite-submit.out)
    echo "TuxSuite test ID: ${TUXID}"
    echo ${TUXID} > ${WORKSPACE}/tux.id
    tuxsuite test logs --raw ${TUXID} > ${WORKSPACE}/lava-raw.log

    if tuxsuite test results ${TUXID} | grep -v "lava.http-download" | grep -q 'fail'; then
        echo "tuxsuite test submit status was: ${status}, failing testcases found, setting as 1 (failed)"
        status=1
    fi

    echo "TuxSuite test result: ${status}"

    exit ${status}
fi

function submit_via_lava_or_squad() {

lavacli identities add --username ${LAVA_USER} --token ${LAVA_TOKEN} --uri "https://${LAVA_SERVER}/RPC2" default

if [ $USE_SQUAD -ne 0 -a -n "${QA_SERVER_VERSION}" ]; then
    # Submit via SQUAD

    if [ -n "${GERRIT_CHANGE_NUMBER}" ] && [ -n "${GERRIT_PATCHSET_NUMBER}" ]; then
        curl \
            --fail \
            --retry 4 \
            -X POST \
            --header "Auth-Token: ${QA_REPORTS_TOKEN}" \
            ${QA_SERVER}/api/createbuild/${QA_SERVER_TEAM}/${QA_SERVER_PROJECT}/${QA_SERVER_VERSION}
    fi

    TESTJOB_ID=$(curl \
        --fail \
        --retry 4 \
        -X POST \
        --header "Auth-Token: ${QA_REPORTS_TOKEN}" \
        --form backend=${LAVA_SERVER} \
        --form definition=@artefacts-lava/job.yaml \
        ${QA_SERVER}/api/submitjob/${QA_SERVER_TEAM}/${QA_SERVER_PROJECT}/${QA_SERVER_VERSION}/${DEVICE_TYPE})

    # SQUAD will send 400, curl error code 22, on bad test definition
    if [ "$?" = "22" ]; then
        echo "Bad test definition!!"
        exit 1
    fi

    if [ -n "${TESTJOB_ID}" ]; then
        echo "TEST JOB URL: ${QA_SERVER}/testjob/${TESTJOB_ID} TEST JOB ID: ${TESTJOB_ID}"


        # The below loop with a sleep is intentional: LAVA could be under heavy load so previous job creation can
        # take 'some' time to get the right numeric LAVA JOB ID
        renumber='^[0-9]+$'
        LAVAJOB_ID="null"
        iter=0
        max_tries=120 # run retries for an hour
        while ! [[ $LAVAJOB_ID =~ $renumber ]]; do
            if [ $iter -eq $max_tries ] ; then
                LAVAJOB_ID=''
                break
            fi
            sleep 30
            LAVAJOB_ID=$(curl --fail --retry 4 ${QA_SERVER}/api/testjobs/${TESTJOB_ID}/?fields=job_id)

            # Get the job_id value (whatever it is)
            LAVAJOB_ID=$(echo ${LAVAJOB_ID} | jq '.job_id')
            LAVAJOB_ID="${LAVAJOB_ID//\"/}"

            iter=$(( iter + 1 ))
        done
    fi
else
    # Submit directly to LAVA
    LAVAJOB_ID=$(resilient_cmd lavacli jobs submit artefacts-lava/job.yaml)
fi


# check that rest query at least get non-empty value
if [ -n "${LAVAJOB_ID}" ]; then

    echo "LAVA URL: https://${LAVA_SERVER}/scheduler/job/${LAVAJOB_ID} LAVA JOB ID: ${LAVAJOB_ID}"


    # if timeout on waiting for LAVA to complete, create an 'artificial' lava.log indicating
    # job ID and timeout seconds
    if ! wait_lava_job ${LAVAJOB_ID}; then
        echo "Stopped monitoring LAVA JOB ${LAVAJOB_ID}, likely stuck or timeout too short?" | tee "${WORKSPACE}/lava.log"
        exit 1
    else
        # Retrieve the test job plain log which is a yaml format file from LAVA
        resilient_cmd sh -c "lavacli jobs logs --raw ${LAVAJOB_ID} > ${WORKSPACE}/lava-raw.log"

        # Fetch and store LAVA job result (1 failure, 0 success)
        resilient_cmd lavacli results ${LAVAJOB_ID} | tee "${WORKSPACE}/lava.results"
        if grep -q '\[fail\]' "${WORKSPACE}/lava.results"; then
            return 1
        else
            return 0
        fi
    fi
else
    echo "LAVA Job ID could not be obtained"
    exit 1
fi

}

# FIXME: Juno and FVP jobs may fail due to non-related users changes,
# so CI needs to resubmit the job, at most three times:
# Juno jobs may fail due to LAVA lab infrastructure issues (see
# https://projects.linaro.org/browse/LSS-2128)
# FVP jobs may hang at some particular TFTF test (see
# https://linaro.atlassian.net/browse/TFC-176)

# UPDATE: We want to keep retrying for LAVA for historical reasons,
# but we want to start from clean page with TuxSuite, so don't
# retry for it for now, and see how it goes.

status=1
for i in $(seq 1 ${LAVA_RETRIES:-3}); do
    echo "# LAVA submission iteration #$i"
    if submit_via_lava_or_squad; then
        status=0
        break
    fi
done

exit ${status}
