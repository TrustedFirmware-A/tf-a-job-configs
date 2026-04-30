def staticChecks(Map args) {
    def script = (args.script ?: 'script/static-checks/static-checks.sh')
    def scriptPath = "${args.ciScripts}/${script}"

    try {
        withEnv([
            'IS_CONTINUOUS_INTEGRATION=1',
            "LOG_TEST_FILENAME=${args.log}",
        ]) {
            sh "bash ${shellQuote(scriptPath)}"
        }
    } finally {
        archiveArtifacts artifacts: args.log,
            allowEmptyArchive: true
    }
}
