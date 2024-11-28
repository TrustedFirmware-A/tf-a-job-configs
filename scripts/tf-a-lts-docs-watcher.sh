#!/bin/bash
set -ex

echo "########################################################################"
echo "    Gerrit Environment"
env | grep '^GERRIT'
echo "########################################################################"

if [ "${GERRIT_PROJECT}" == "TF-A/trusted-firmware-a" ]; then
    # For real production project, non-sandbox run goes to production RTD project,
    # while for sandbox run to a separate RTD project.
    if [ "${SANDBOX_RUN}" == "false" ]; then
        RTD_PROJECT="trustedfirmware-a"
        RTD_WEBHOOK_URL="https://readthedocs.org/api/v2/webhook/trustedfirmware-a/87181/"
        RTD_WEBHOOK_SECRET_KEY=${RTD_WEBHOOK_SECRET}
        RTD_API_TOKEN=${RTD_API_TOKEN}
    else
        RTD_PROJECT="trustedfirmware-a-sandbox"
        RTD_WEBHOOK_URL="https://readthedocs.org/api/v2/webhook/trustedfirmware-a-sandbox/263958/"
        RTD_WEBHOOK_SECRET_KEY=${TFA_SANDBOX_RTD_WEBHOOK_SECRET}
        RTD_API_TOKEN=${PFALCON_RTD_API_TOKEN}
    fi
elif [ "${GERRIT_PROJECT}" == "sandbox/pfalcon/trusted-firmware-a" ]; then
    # For test project, both "production" and "sandbox" go to the same elsewhere project.
    RTD_PROJECT="pfalcon-trustedfirmware-a-sandbox"
    RTD_WEBHOOK_URL="https://readthedocs.org/api/v2/webhook/pfalcon-trustedfirmware-a-sandbox/263459/"
    RTD_WEBHOOK_SECRET_KEY=${PFALCON_RTD_WEBHOOK_SECRET}
    RTD_API_TOKEN=${PFALCON_RTD_API_TOKEN}
else
    echo "Unknown GERRIT_PROJECT: ${GERRIT_PROJECT}"
    exit 1
fi

RTD_API="https://readthedocs.org/api/v3/projects/${RTD_PROJECT}"
RTD_VER_API="${RTD_API}/versions"

new_tag=""
new_slug=""
refname=${GERRIT_REFNAME##*/}
lts_branch=${refname}
if echo ${GERRIT_REFNAME} | grep -q "refs/tags/"; then
    new_tag=${GERRIT_REFNAME#refs/tags/}
    # Convert tag to ReadTheDocs version slug
    new_slug=$(echo ${new_tag} | tr '[A-Z]/' '[a-z]-')
    lts_branch=${refname%.*}
fi

function activate_version() {
    version=$1
    max_retry_time=20
    retry=0

    ver_slug=$(curl -s -H "Authorization: Token ${RTD_API_TOKEN}" ${RTD_VER_API}/${version}/ | \
                 jq -r '.slug')

    while [ "${ver_slug}" != "${version}" ];
    do
        [ ${retry} -gt ${max_retry_time} ] && break 
        sleep 30
        retry=$((retry+1))
        ver_slug=$(curl -s -H "Authorization: Token ${RTD_API_TOKEN}" ${RTD_VER_API}/${version}/ | \
                     jq -r '.slug')
    done

    if [ ${retry} -le ${max_retry_time} ]; then
        echo "Active new version: ${version}"
        curl -s -X PATCH -H "Content-Type: application/json" -H "Authorization: Token ${RTD_API_TOKEN}" \
             -d "{\"active\": true, \"hidden\": false}" ${RTD_VER_API}/${version}/
    else
        echo "RTD can not find the version: ${version}"
        exit 1
    fi
}

function wait_for_build() {
    version=$1
    retry=0
    while true; do
        status=$(curl -s -H "Authorization: Token ${RTD_API_TOKEN}" "${RTD_API}/builds/" | \
                   jq -r ".results | map(select(.version==\"$version\")) | .[0].state.code")
        echo $status
        if [ "$status" == "finished" ]; then
            break
        fi

        retry=$((retry + 1))
        if [ $retry -gt 40 ]; then
            echo "Could not confirm that ReadTheDoc slug ${version} was built in the alloted time."
            break
        fi

        sleep 30
    done
}

echo "Notifying ReadTheDocs of changes on: ${lts_branch}"
build_trigger=$(curl -s -X POST -d "branches=${lts_branch}" -d "token=${RTD_WEBHOOK_SECRET_KEY}" ${RTD_WEBHOOK_URL} | jq .build_triggered)
if [ "${build_trigger}" = "false" ]; then
    # The branch might be new and hasn't been known by RTD, or hasn't been activated, or both
    # we can trigger a build for the master branch to update all branches
    echo "The branch ${lts_branch} is new! Activate and hide it!"
    curl -s -X POST -d "branches=master" -d "token=${RTD_WEBHOOK_SECRET_KEY}" ${RTD_WEBHOOK_URL}
    activate_version ${lts_branch}
    curl -s -X PATCH -H "Content-Type: application/json" -H "Authorization: Token ${RTD_API_TOKEN}" \
         -d "{\"hidden\": true}" ${RTD_VER_API}/${lts_branch}/
fi

# Triggered by a new tag
if [ -n "${new_tag}" ]; then
    echo -e "\nNew release tag: ${new_tag}, slug: ${new_slug}"
    # Hide the current active and unhidden tags
    old_tags=$(curl -s -H "Authorization: Token ${RTD_API_TOKEN}" "${RTD_VER_API}/?slug=${lts_branch}&type=tag&active=true" | \
                   jq -r '.results | map(select(.hidden == false) | .slug) | .[]')
    for t in ${old_tags};
    do
        echo "Hide old tag: ${t}"
        curl -s -X PATCH -H "Content-Type: application/json" -H "Authorization: Token ${RTD_API_TOKEN}" \
                 -d "{\"hidden\": true}" ${RTD_VER_API}/${t}/
    done
    # Active the new version
    echo "Active new version: ${new_slug}"
    activate_version ${new_slug}

    wait_for_build ${new_slug}
    echo "Docs for the new release are available at: https://${RTD_PROJECT}.readthedocs.io/en/${new_slug}/"
fi

