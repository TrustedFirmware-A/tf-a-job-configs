#!/bin/bash

set -xe

if [ -f "${WORKSPACE}/lava-raw.log" ]; then

                # Split the UART messages to the corresponding log files
                ${WORKSPACE}/tf-a-job-configs/tf-a-builder/log-splitter.py "${WORKSPACE}/lava-raw.log"

                PROJECT_WORKSPACE=${WORKSPACE}
                # Take possible code coverage trace data from the LAVA log
                ${WORKSPACE}/tf-a-job-configs/tf-a-builder/feedback-trace-splitter.sh \
                            ${PROJECT_WORKSPACE} \
                            ${WORKSPACE} \
                            ${TF_GERRIT_REFSPEC}

                # Generate Code Coverate Report in case there are traces available
                if find covtrace-*.log; then
                    reporting="${WORKSPACE}/tf-a-ci-scripts/contrib/qa-tools/coverage-tool/coverage-reporting"

                    mkdir -p "${WORKSPACE}/trace_report"

                    python3 "${reporting}/intermediate_layer.py" \
                        --config-json "${WORKSPACE}/config_file.json" \
                        --local-workspace "${PROJECT_WORKSPACE}"

                    python3 "${reporting}/generate_info_file.py" \
                        --workspace "${PROJECT_WORKSPACE}" \
                        --json "${WORKSPACE}/output_file.json" \
                        --info "${WORKSPACE}/trace_report/coverage.info"

                    "${WORKSPACE}/tf-a-ci-scripts/script/relativize-lcov.sh" \
                        "${WORKSPACE}/trace_report/coverage.info"

                    find ${WORKSPACE}/trace_report
                fi

fi
