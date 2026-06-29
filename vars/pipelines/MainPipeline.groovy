def mainPipeline(Map args) {
    catchError {
        stage('Static Checks') {
            node(args.builderNode) {
                def ciScripts

                dir('tf-a-ci-scripts') {
                    checkout gerrit(
                        host: params.GERRIT_HOST ?: 'review.trustedfirmware.org',
                        project: params.CI_GERRIT_PROJECT,
                        ref: params.CI_REFSPEC,
                    )

                    ciScripts = pwd()
                }

                dir('source') {
                    checkout gerrit

                    staticChecks ciScripts: ciScripts, log: 'static-checks.log'
                }
            }
        }
    }

    catchError {
        stage('Gateway Tests') {
            gatewayPipeline(
                builderJob: args.builderJob,
                testGroups: args.testGroups,
            )
        }
    }

    catchError {
        stage('Visualizations') {
            parallel([
                'Lines of Code': {
                    build job: 'tf-a-sloc-visualization', parameters: [
                        string(name: 'GERRIT_PROJECT', value: params.GERRIT_PROJECT),
                        string(name: 'GERRIT_REFSPEC', value: params.GERRIT_REFSPEC),
                    ]
                },

                'Test Category': {
                    build job: 'tf-a-test-category-visualization'
                },
            ])
        }
    }
}
