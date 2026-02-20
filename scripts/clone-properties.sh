#!/usr/bin/env bash

#
# Print Java-style properties which translate Gerrit trigger parameters into
# variable names used by `clone.sh`, based on the active project.
#
# These properties are injected as environment variables into the job by the
# EnvInject plugin.
#

set -eux -o pipefail

declare -A projects=(
    ["arm-firmware-crates/arm-cci"]="ARM_CCI_GERRIT_PROJECT"
    ["arm-firmware-crates/arm-ffa"]="ARM_FFA_GERRIT_PROJECT"
    ["arm-firmware-crates/arm-fvp-base-pac"]="ARM_FVP_BASE_PAC_GERRIT_PROJECT"
    ["arm-firmware-crates/arm-generic-timer"]="ARM_GENERIC_TIMER_GERRIT_PROJECT"
    ["arm-firmware-crates/arm-gic"]="ARM_GIC_GERRIT_PROJECT"
    ["arm-firmware-crates/arm-mhu"]="ARM_MHU_GERRIT_PROJECT"
    ["arm-firmware-crates/arm-pl011-uart"]="ARM_PL011_UART_GERRIT_PROJECT"
    ["arm-firmware-crates/arm-pl061"]="ARM_PL061_GERRIT_PROJECT"
    ["arm-firmware-crates/arm-psci"]="ARM_PSCI_GERRIT_PROJECT"
    ["arm-firmware-crates/arm-scmi"]="ARM_SCMI_GERRIT_PROJECT"
    ["arm-firmware-crates/arm-sp805"]="ARM_SP805_GERRIT_PROJECT"
    ["arm-firmware-crates/arm-sysregs"]="ARM_SYSREGS_GERRIT_PROJECT"
    ["arm-firmware-crates/arm-tzc"]="ARM_TZC_GERRIT_PROJECT"
    ["ci/tf-a-ci-scripts"]="CI_GERRIT_PROJECT"
    ["hafnium/hafnium"]="SPM_GERRIT_PROJECT"
    ["RF-A/rusted-firmware-a"]="RF_GERRIT_PROJECT"
    ["rust-spmc/arm-xlat"]="ARM_XLAT_GERRIT_PROJECT"
    ["rust-spmc/firmware-development-guide"]="ARM_FW_DEV_GUIDE_GERRIT_PROJECT"
    ["shared/tf-firmware-handoff"]="TF_FIRMWARE_HANDOFF_GERRIT_PROJECT"
    ["TF-A/tf-a-tests"]="TFTF_GERRIT_PROJECT"
    ["TF-A/trusted-firmware-a"]="TF_GERRIT_PROJECT"
    ["TF-M/tf-m-extras"]="TF_M_EXTRAS_GERRIT_PROJECT"
    ["TF-M/tf-m-tests"]="TF_M_TESTS_GERRIT_PROJECT"
    ["TF-RMM/tf-rmm"]="RMM_GERRIT_PROJECT"
)

declare -A refspecs=(
    ["arm-firmware-crates/arm-cci"]="ARM_CCI_GERRIT_REFSPEC"
    ["arm-firmware-crates/arm-ffa"]="ARM_FFA_GERRIT_REFSPEC"
    ["arm-firmware-crates/arm-fvp-base-pac"]="ARM_FVP_BASE_PAC_GERRIT_REFSPEC"
    ["arm-firmware-crates/arm-generic-timer"]="ARM_GENERIC_TIMER_GERRIT_REFSPEC"
    ["arm-firmware-crates/arm-gic"]="ARM_GIC_GERRIT_REFSPEC"
    ["arm-firmware-crates/arm-mhu"]="ARM_MHU_GERRIT_REFSPEC"
    ["arm-firmware-crates/arm-pl011-uart"]="ARM_PL011_UART_GERRIT_REFSPEC"
    ["arm-firmware-crates/arm-pl061"]="ARM_PL061_GERRIT_REFSPEC"
    ["arm-firmware-crates/arm-psci"]="ARM_PSCI_GERRIT_REFSPEC"
    ["arm-firmware-crates/arm-scmi"]="ARM_SCMI_GERRIT_REFSPEC"
    ["arm-firmware-crates/arm-sp805"]="ARM_SP805_GERRIT_REFSPEC"
    ["arm-firmware-crates/arm-sysregs"]="ARM_SYSREGS_GERRIT_REFSPEC"
    ["arm-firmware-crates/arm-tzc"]="ARM_TZC_GERRIT_REFSPEC"
    ["ci/tf-a-ci-scripts"]="CI_REFSPEC"
    ["hafnium/hafnium"]="SPM_REFSPEC"
    ["RF-A/rusted-firmware-a"]="RFA_REFSPEC"
    ["rust-spmc/arm-xlat"]="ARM_XLAT_GERRIT_REFSPEC"
    ["rust-spmc/firmware-development-guide"]="ARM_FW_DEV_GUIDE_GERRIT_REFSPEC"
    ["shared/tf-firmware-handoff"]="TF_FIRMWARE_HANDOFF_GERRIT_REFSPEC"
    ["TF-A/tf-a-tests"]="TFTF_GERRIT_REFSPEC"
    ["TF-A/trusted-firmware-a"]="TF_GERRIT_REFSPEC"
    ["TF-M/tf-m-extras"]="TF_M_EXTRAS_GERRIT_REFSPEC"
    ["TF-M/tf-m-tests"]="TF_M_TESTS_GERRIT_REFSPEC"
    ["TF-RMM/tf-rmm"]="RMM_REFSPEC"
)

for project in "${!projects[@]}"; do
    projects["next/${project}"]="${projects["${project}"]}"
    refspecs["next/${project}"]="${refspecs["${project}"]}"
done

if [[ -v GERRIT_REFNAME ]]; then
    GERRIT_REFSPEC="${GERRIT_REFNAME}"
fi

printf '%s=%s\n' "${projects["${GERRIT_PROJECT:?}"]}" "${GERRIT_PROJECT:?}"
printf '%s=%s\n' "${refspecs["${GERRIT_PROJECT:?}"]}" "${GERRIT_REFSPEC:?}"
