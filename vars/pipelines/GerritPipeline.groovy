def gerritPipeline(Map args) {
    def ciScriptsConfig = args.ciScripts
    def gerritChange = args.gerrit

    if (args.commitLint) {
        stage('Commit Lint') {
            catchError(catchInterruptions: false) {
                build commitlint(
                    project: gerritChange.project,

                    refspec: gerritChange.refspec,
                    refname: gerritChange.revision,
                    refnameBase: "origin/${gerritChange.branch}",
                )
            }
        }
    }

    stage('Static Checks') {
        catchError(catchInterruptions: false) {
            node(args.builderNode) {
                def staticChecksConfig = args.staticChecks ?: [:]
                def staticChecksLog = staticChecksConfig.log ?: 'static-checks.log'
                def ciScripts

                dir('tf-a-ci-scripts') {
                    checkout gerrit(
                        project: ciScriptsConfig.project,
                        refspec: ciScriptsConfig.refspec,
                    )

                    ciScripts = pwd()
                }

                dir('source') {
                    checkout gerrit(
                        project: gerritChange.project,
                        branch: gerritChange.branch,
                        refspec: gerritChange.refspec,
                    )

                    staticChecks(staticChecksConfig + [
                        ciScripts: ciScripts,
                        log: staticChecksLog,
                    ])
                }
            }
        }
    }

    def testGroups = (1..gerritLabel('Allow-CI')).collect { level ->
        "${args.ciScriptsTestPrefix}-l${level}-*"
    }

    gatewayPipeline(
        builderJob: args.builderJob,

        builderParams: [
            TF_GERRIT_PROJECT: args.tfa.project,
            TF_GERRIT_REFSPEC: args.tfa.refspec,

            RF_GERRIT_PROJECT: args.rfa.project,
            RFA_REFSPEC: args.rfa.refspec,

            TFUT_GERRIT_PROJECT: args.tfut.project,
            TFUT_GERRIT_REFSPEC: args.tfut.refspec,

            TFTF_GERRIT_PROJECT: args.tftf.project,
            TFTF_GERRIT_REFSPEC: args.tftf.refspec,

            TF_M_TESTS_GERRIT_PROJECT: args.tfmTests.project,
            TF_M_TESTS_GERRIT_REFSPEC: args.tfmTests.refspec,

            TF_M_EXTRAS_GERRIT_PROJECT: args.tfmExtras.project,
            TF_M_EXTRAS_GERRIT_REFSPEC: args.tfmExtras.refspec,

            SPM_GERRIT_PROJECT: args.hafnium.project,
            SPM_REFSPEC: args.hafnium.refspec,

            RMM_GERRIT_PROJECT: args.rmm.project,
            RMM_REFSPEC: args.rmm.refspec,

            CI_GERRIT_PROJECT: args.ciScripts.project,
            CI_REFSPEC: args.ciScripts.refspec,

            MBEDTLS_URL: args.mbedtlsUrl,
        ],

        testGroups: testGroups,
    )
}
