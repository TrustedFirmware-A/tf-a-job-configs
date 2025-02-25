#!/bin/bash

set -xe

pip install -U tuxput
# The build stage of this job has generated some artifacts under artefacts-lava.
# Use tpcli and the "upload" URL to upload these artifacts to the S3 bucket.
# tpcli seems to only accept files that are in the current directory, therefore cd into artefacts-lava.
cd ${WORKSPACE}/artefacts-lava
/home/buildslave/.local/bin/tpcli -t ${TUXPUT_ARCHIVE_TOKEN} -b ${TUXPUB_S3_BUCKET} "$URL_FIP" fip.bin
/home/buildslave/.local/bin/tpcli -t ${TUXPUT_ARCHIVE_TOKEN} -b ${TUXPUB_S3_BUCKET} "$URL_BL1" bl1.bin
cd -
