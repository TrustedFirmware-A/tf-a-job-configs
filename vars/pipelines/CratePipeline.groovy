def cratePipeline(Map args) {
    def features = args.features ?: []

    stage('Crate Tests') {
        node('docker-amd64-tf-a-jammy') {
            def ciScripts

            dir('tf-a-ci-scripts') {
                checkout gerrit(
                    project: 'ci/tf-a-ci-scripts',
                    branch: 'master'
                )

                ciScripts = pwd()
            }

            dir(args.name) {
                checkout gerrit(
                    project: args.gerrit.project,
                    branch: args.gerrit.branch,
                    refspec: args.gerrit.refspec,
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
