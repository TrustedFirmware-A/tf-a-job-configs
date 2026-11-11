#!/bin/bash
set -x

echo "########################################################################"
echo "    Gerrit Environment"
env | grep '^GERRIT'
echo "########################################################################"

set -e

if [ "${GERRIT_PROJECT}" != "${GERRIT_PROJECT_PREFIX:-}TF-A/trusted-firmware-a" ]; then
    echo "Unknown GERRIT_PROJECT: ${GERRIT_PROJECT}"
    exit 1
fi

RTD_PROJECT="trustedfirmware-a"
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

function rtd_rest_api() {
    uri="$1"
    jqfilt="$2"
    resp=$(curl -s -H "Authorization: Token ${RTD_API_TOKEN}" "$uri")
    echo $resp 1>&2
    echo $resp | jq -r "$jqfilt"
}

function activate_version() {
    version=$1
    max_retry_time=20
    retry=0

    # Check whether we need to activate a tag or a branch. If it's a tag, create a branch variable
    echo ${version} | grep -q "lts-v[0-9].*\.[0-9].*\.[0-9].*" && branch=${version%.*}

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

    # activate and hide the branch
    if [ -n "${branch}" ]; then
        curl -s -X PATCH -H "Content-Type: application/json" -H "Authorization: Token ${RTD_API_TOKEN}" \
             -d "{\"active\": true, \"hidden\": true}" ${RTD_VER_API}/${branch}/
    fi

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

echo "Notifying ReadTheDocs of changes"
curl -s -X POST -H "Authorization: Token ${RTD_API_TOKEN}" ${RTD_VER_API}/${lts_branch}/builds/

# Triggered by a new tag
if [ -n "${new_tag}" ]; then
    echo -e "\nNew release tag: ${new_tag}, slug: ${new_slug}"
    # Hide the current active and visible version
    old_tags=$(rtd_rest_api "${RTD_VER_API}/?slug=${lts_branch}&type=tag&active=true" '.results | map(select(.hidden == false) | .slug) | .[]')
    for t in ${old_tags};
    do
        echo "Hide old version: ${t}"
        curl -s -X PATCH -H "Content-Type: application/json" -H "Authorization: Token ${RTD_API_TOKEN}" \
                 -d "{\"hidden\": true}" ${RTD_VER_API}/${t}/
    done
    # Active the new version
    echo "Active new version: ${new_slug}"
    activate_version ${new_slug}

    wait_for_build ${new_slug}
    echo "Docs for the new release are available at: https://${RTD_PROJECT}.readthedocs.io/en/${new_slug}/"
fi
