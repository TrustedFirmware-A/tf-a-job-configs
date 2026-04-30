def mainPipeline(Map args) {
    catchError {
        stage('Static Checks') {
            node(args.builderNode) {
                def ciScripts

                dir('tf-a-ci-scripts') {
                    checkout gerrit(
                        project: params.CI_GERRIT_PROJECT,
                        refspec: params.CI_REFSPEC,
                    )

                    ciScripts = pwd()
                }

                dir('source') {
                    checkout gerrit(
                        host: 'review.trustedfirmware.org',

                        project: params.GERRIT_PROJECT,
                        refspec: params.GERRIT_REFSPEC,
                    )

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

                'Test Result': {
                    build job: 'tf-a-test-result-visualization', parameters: [
                        string(name: 'GERRIT_PROJECT', value: params.GERRIT_PROJECT),
                        string(name: 'GERRIT_REFSPEC', value: params.GERRIT_REFSPEC),

                        string(name: 'TF_GERRIT_PROJECT', value: params.TF_GERRIT_PROJECT),
                        string(name: 'TF_GERRIT_BRANCH', value: params.TF_GERRIT_BRANCH),
                        string(name: 'TF_GERRIT_REFSPEC', value: params.TF_GERRIT_REFSPEC),

                        string(name: 'TFTF_GERRIT_PROJECT', value: params.TFTF_GERRIT_PROJECT),
                        string(name: 'TFTF_GERRIT_BRANCH', value: params.TFTF_GERRIT_BRANCH),
                        string(name: 'TFTF_GERRIT_REFSPEC', value: params.TFTF_GERRIT_REFSPEC),

                        string(name: 'CI_GERRIT_PROJECT', value: params.CI_GERRIT_PROJECT),
                        string(name: 'CI_REFSPEC', value: params.CI_REFSPEC),

                        string(name: 'TARGET_BUILD', value: "${env.JOB_NAME}/${env.BUILD_NUMBER}"),
                    ]
                },
            ])
        }
    }
}
