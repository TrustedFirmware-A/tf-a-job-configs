#!/bin/bash
set -ex

echo "########################################################################"
echo "    Gerrit Environment"
env |grep '^GERRIT'
echo "########################################################################"

RTD_WEBHOOK_URL="https://readthedocs.org/api/v2/webhook/trustedfirmware-a/87181/"
RTD_VER_API="https://readthedocs.org/api/v3/projects/trustedfirmware-a/versions"
RTD_WEBHOOK_SECRET_KEY=${RTD_WEBHOOK_SECRET}
RTD_API_TOKEN=${RTD_API_TOKEN}

new_tag=""
refname=${GERRIT_REFNAME##*/}
lts_branch=${refname}
echo ${GERRIT_REFNAME} | grep -q "refs\/tags\/" && lts_branch=${refname%.*} && new_tag=${refname}

function activate_version() {
    version=$1
    max_retry_time=20
    retry=0

    ver_status=$(curl -s -H "Authorization: Token ${RTD_API_TOKEN}" ${RTD_VER_API}/${version}/ | \
                 jq -r '.detail')

    while [ "${ver_status}" == "Not found." ];
    do
        [ ${retry} -gt ${max_retry_time} ] && break 
        sleep 30
        retry=$((retry+1))
        ver_status=$(curl -s -H "Authorization: Token ${RTD_API_TOKEN}" ${RTD_VER_API}/${version}/ | \
                     jq -r '.detail')
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

echo "Notifying ReadTheDocs of changes on: ${lts_branch}"
build_trigger=$(curl -s -X POST -d "branches=${lts_branch}" -d "token=${RTD_WEBHOOK_SECRET_KEY}" ${RTD_WEBHOOK_URL} | jq .build_triggered)
if [ "${build_trigger}" = "false" ]; then
	# The branch might be new and hasn't been known by RTD, or hasn't been activated, or both
    # we can trigger a build for the master branch to update all branches
	echo "The branch ${lts_branch} is now! Activate and hide it!"
    curl -s -X POST -d "branches=master" -d "token=${RTD_WEBHOOK_SECRET_KEY}" ${RTD_WEBHOOK_URL}
    activate_version ${lts_branch}
    curl -s -X PATCH -H "Content-Type: application/json" -H "Authorization: Token ${RTD_API_TOKEN}" \
         -d "{\"hidden\": true}" ${RTD_VER_API}/${lts_branch}/
fi

# Triggered by a new tag
if [ -n "${new_tag}" ]; then
    echo -e "\nNew release tag: ${new_tag}"
    # Hide the current active and unhidden tags
    old_tags=$(curl -s -H "Authorization: Token ${RTD_API_TOKEN}" "${RTD_VER_API}/?slug=${lts_branch}&type=tag&active=true" | \
    		   jq -r '.results | map(select(.hidden == false) | .verbose_name) | .[]')
    for t in ${old_tags};
    do
        echo "Hide old tag: ${t}"
        curl -s -X PATCH -H "Content-Type: application/json" -H "Authorization: Token ${RTD_API_TOKEN}" \
        	 -d "{\"hidden\": true}" ${RTD_VER_API}/${t}/
    done
    # Active the new version
    echo "Active new version: ${new_tag}"
    activate_version ${new_tag}
fi

