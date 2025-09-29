#!/bin/bash
set -ex

echo "########################################################################"
echo "    Gerrit Environment"
env |grep '^GERRIT'
echo "########################################################################"
SSH_PARAMS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PubkeyAcceptedKeyTypes=+ssh-rsa -p 29418 -i ${CI_BOT_KEY}"
GERRIT_URL="review.trustedfirmware.org"
GERRIT_CHANGE_URL_BASE=${GERRIT_CHANGE_URL%/*}
GERRIT_QUERY_PARAMS="--dependencies --current-patch-set --format=JSON change:"
QUERY_DEPENDENCY_CMD="${SSH_PARAMS} ${CI_BOT_USERNAME}@${GERRIT_URL} gerrit query ${GERRIT_QUERY_PARAMS}"
ALLOW_CI_COMMENT="Trigger Allow-CI job by ${BUILD_URL}"
VOTE_ALLOW_CI_CMD="${SSH_PARAMS} ${CI_BOT_USERNAME}@${GERRIT_URL} gerrit review --label ${ALLOW_CI_JOB} -m \"${ALLOW_CI_COMMENT}\" ${GERRIT_PATCHSET_REVISION}"
SUBMIT_COMMENT="Submit patch by ${BUILD_URL}"
err_msg=$(mktemp)

function get_top_patch() {
    # Get the top of the patch stack
    # return: change_no,commit_revision
    local change_no=$1

    patch_info=$(ssh ${QUERY_DEPENDENCY_CMD}${change_no} 2>/dev/null| jq -n 'input')
    revision=$(echo ${patch_info} | jq -r '.currentPatchSet.revision')
    ret=${change_no},${revision}

    neededBy=$(echo ${patch_info} | jq -c 'select(.neededBy)')
    while [ -n "${neededBy}" ];
    do
        change_no=$(echo ${neededBy} | jq -r '.neededBy[0].number')
        revision=$(echo ${neededBy} | jq -r '.neededBy[0].revision')
        ret=${change_no},${revision}
        neededBy=$(ssh ${QUERY_DEPENDENCY_CMD}${change_no} 2>/dev/null | jq -c 'select(.neededBy)')
    done

    echo ${ret}
}

function check_ok_to_submit() {
    # Check if this patch meets the submit requirement
    # The submit requirement is
    # Verified: 1
    # Code-Owner-Review: 1
    # Maintainer-Review: 1
    # return:
    #   "True":     if the submit requirement is met
    #   "False:     if the submit requirement is not met
    #   "MERGED":   if the patch has been merged
    local change_no=$1

    patch_info=$(ssh ${QUERY_DEPENDENCY_CMD}${change_no} 2>/dev/null | jq -n 'input')
    patch_votes=$(echo ${patch_info} | jq -c 'select(.currentPatchSet.approvals)')

    if [ $(echo ${patch_info} | jq -r '.status') == "MERGED" ]; then
        echo "MERGED"
    elif  test -n "${patch_votes}" &&
        jq -e '.currentPatchSet.approvals[] | select(.type == "Code-Owner-Review" and .value == "1")' <<< "${patch_votes}" > /dev/null &&
        jq -e '.currentPatchSet.approvals[] | select(.type == "Maintainer-Review" and .value == "1")' <<< "${patch_votes}" > /dev/null &&
        jq -e '.currentPatchSet.approvals[] | select(.type == "Verified" and .value == "1")' <<< "${patch_votes}" > /dev/null; then
        echo "True"
    else
        echo "${GERRIT_CHANGE_URL_BASE}/${change_no} doesn't meet the submit requirement" >> /dev/stderr
        echo "False"
    fi
}

function submit_patch_stack() {
    # Check the whole patch stack from top to bottom
    # to see if all patches meet the submit requirements
    local change_no=$1
    local can_merge="True"

    top_patch=$(get_top_patch ${change_no})
    top_patch_no=$(echo ${top_patch} | cut -d ',' -f 1)
    top_patch_rev=$(echo ${top_patch} | cut -d ',' -f 2)

    patch_to_be_checked=${top_patch_no}
    while [ -n "${patch_to_be_checked}" ];
    do
        set +x  # disable debugging log to prevent comtaminate the message we want to keep
        can_submit=$(check_ok_to_submit ${patch_to_be_checked} 2>> ${err_msg})
        set -x
        # The patch that we just checked was merged, exit the loop
        [ "${can_submit}" == "MERGED" ] && break
        [ "${can_merge}" == "True" ] && can_merge=${can_submit}
        patch_to_be_checked=$(ssh ${QUERY_DEPENDENCY_CMD}${patch_to_be_checked} 2>/dev/null | jq 'select(.dependsOn) | .dependsOn[].number' )
    done
    if [ "${can_merge}" == "True" ]; then
        # Check the patch stack agein to ensure it hasn't been merged yet
        if [ $(ssh ${QUERY_DEPENDENCY_CMD}${top_patch_no} | jq -r 'select(.status)|.status') != "MERGED" ];then
            echo "The whole patch stack meets the submit requirements, merge it"
            ssh ${SSH_PARAMS} ${CI_BOT_USERNAME}@${GERRIT_URL} gerrit review ${top_patch_rev} --message "\"${SUBMIT_COMMENT}\"" --submit 2>err.log || \
            (ssh ${SSH_PARAMS} ${CI_BOT_USERNAME}@${GERRIT_URL} gerrit review ${top_patch_rev} \
             --label Verified=-1 --message "\"$(cat err.log)\""; exit 1)
        else
            echo "The whole patch stack has been merged!"
        fi
    else
        echo "The patch stack can not be merged!"
        cat ${err_msg}
    fi
}

function trigger_allow_ci_on_top_of_patch_stack() {
    # This function will set ${ALLOW_CI_JOB} on the
    # top of the patch stack or a single patch
    local change_no=$1

    neededBy=$(ssh ${QUERY_DEPENDENCY_CMD}${change_no} 2>/dev/null | jq -c 'select(.neededBy)')
    if [ -z "${neededBy}" ]; then
        echo -e "Trigger Allow-CI job on ${GERRIT_CHANGE_URL}"
        ssh ${VOTE_ALLOW_CI_CMD} 2>/dev/null
    else
        echo "This patch is not on the top of a patch stack"
    fi
}

case ${GERRIT_EVENT_TYPE} in
    "comment-added")
        echo "Triggered by comment-added"
        # Check eack patch. if all patches meet the submit requirements
        # merge it
        if [ "${ENABLE_PATCH_AUTO_SUBMISSION}" == "true" ]; then
            submit_patch_stack ${GERRIT_CHANGE_NUMBER}
        else
            echo "Patch auto submission function is disabled"
        fi
        ;;
    "patchset-created")
        echo "Triggered by patchset-created"
        # New patch / patch stack is created
        # Set Allow-CI on the top of it
        if [ "${ENABLE_AUTO_ALLOW_CI_JOB}" == "true" ]; then
            trigger_allow_ci_on_top_of_patch_stack ${GERRIT_CHANGE_NUMBER}
        else
            echo "Allow-CI job auto submission function is disabled"
        fi
        ;;
esac
rm -f ${err_msg}
