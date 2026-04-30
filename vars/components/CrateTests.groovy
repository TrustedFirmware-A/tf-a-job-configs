def crateTests(Map args) {
    def features = args.features.join(',')

    try {
        withEnv([
            'IS_CONTINUOUS_INTEGRATION=1',
            "LOG_TEST_FILENAME=${pwd()}/next-generic-checks.log",
            "TEST_FEATURES=${features}",
            "TEST_REPO_PROJECT=${args.project}",
            "TEST_REPO_NAME=${args.name}",
            "CI_SCRIPTS=${args.ciScripts}",
        ]) {
            sh '''
                bash "${CI_SCRIPTS}/script/next-checks/next-checks-generic-tests.sh" \
                    "${TEST_REPO_PROJECT}" "${TEST_REPO_NAME}"
            '''
        }
    } finally {
        archiveArtifacts artifacts: args.log,
            allowEmptyArchive: true
    }
}
