def mainPipeline(Map args) {
    def ciScriptsRefspec

    stage('Static Checks') {
        node(args.builderNode) {
            ciScriptsRefspec = resolveTopicRefspec(
                params.CI_GERRIT_PROJECT,
                params.CI_REFSPEC,
            )

            catchError {
                def ciScripts

                dir('tf-a-ci-scripts') {
                    checkout gerrit(
                        host: params.GERRIT_HOST ?: 'review.trustedfirmware.org',
                        project: params.CI_GERRIT_PROJECT,
                        ref: ciScriptsRefspec,
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
                ciScriptsRefspec: ciScriptsRefspec,
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
