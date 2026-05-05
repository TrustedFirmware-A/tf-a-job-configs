def cratePipeline(Map args) {
    def features = args.features ?: []

    stage('Crate Tests') {
        node('docker-amd64-tf-a-jammy') {
            def ciScripts

            dir('tf-a-ci-scripts') {
                checkout gerrit(
                    host: args.gerrit.host,
                    project: 'ci/tf-a-ci-scripts',
                    ref: 'master',
                )

                ciScripts = pwd()
            }

            dir(args.name) {
                checkout gerrit(
                    host: args.gerrit.host,
                    project: args.gerrit.project,
                    ref: args.gerrit.refspec,
                    branch: args.gerrit.branch,
                )
            }

            crateTests(
                ciScripts: ciScripts,
                log: 'next-generic-checks.log',

                project: args.project,
                name: args.name,
                features: features,
            )
        }
    }
}
