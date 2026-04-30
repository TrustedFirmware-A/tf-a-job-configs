def gatewayTests(Map args) {
    def tests = args.testNames

    if (args.testGroups) {
        dir('tf-a-toolbox') {
            def includes = args.testGroups.collect {
                "--include ${shellQuote(it)}"
            }.join(' ')

            def output = sh(
                script: "uv run --no-dev --extra cli -- tf-a-toolbox matrix groups ${includes}",
                returnStdout: true,
            ).trim()

            tests += output.readLines()
        }
    }

    withEnv([
        "workspace=${pwd()}",
        "test_groups=${tests.join(' ')}",
    ]) {
        sh 'uv run -- "script/gen_test_desc.py"'
    }

    findFiles(glob: '*.testprop').collect {
        readProperties(file: it.path, interpolate: false)
    }
}

def gatewayBuilders(Map args) {
    args.builders.collectEntries { props ->
        def desc = props.TEST_DESC.split('%', 3)
        def name = "${desc[1]}/${props.TEST_CONFIG}"

        [(name): {
            def parameters = args.builderParams + props

            build job: args.builderJob,
                parameters: parameters.collect { key, value ->
                    string(name: key.toString(), value: value.toString())
                }
        }]
    }
}

def gatewayPipeline(Map args) {
    def gerritParamNames = [
        'GERRIT_EVENT_HASH',
        'GERRIT_EVENT_TYPE',

        'GERRIT_HOST',
        'GERRIT_NAME',
        'GERRIT_PORT',
        'GERRIT_SCHEME',
        'GERRIT_VERSION',

        'GERRIT_EVENT_ACCOUNT',
        'GERRIT_EVENT_ACCOUNT_EMAIL',
        'GERRIT_EVENT_ACCOUNT_NAME',
        'GERRIT_EVENT_ACCOUNT_USERNAME',

        'GERRIT_PROJECT',
        'GERRIT_REFSPEC',
        'GERRIT_BRANCH',

        'GERRIT_TOPIC',
        'GERRIT_HASHTAGS',

        'GERRIT_CHANGE_ID',
        'GERRIT_CHANGE_NUMBER',
        'GERRIT_CHANGE_PRIVATE_STATE',
        'GERRIT_CHANGE_SUBJECT',
        'GERRIT_CHANGE_URL',
        'GERRIT_CHANGE_WIP_STATE',
        'GERRIT_CHANGE_COMMIT_MESSAGE',

        'GERRIT_CHANGE_OWNER',
        'GERRIT_CHANGE_OWNER_EMAIL',
        'GERRIT_CHANGE_OWNER_NAME',
        'GERRIT_CHANGE_OWNER_USERNAME',

        'GERRIT_PATCHSET_NUMBER',
        'GERRIT_PATCHSET_REVISION',

        'GERRIT_PATCHSET_UPLOADER',
        'GERRIT_PATCHSET_UPLOADER_EMAIL',
        'GERRIT_PATCHSET_UPLOADER_NAME',
        'GERRIT_PATCHSET_UPLOADER_USERNAME',
    ]

    def builderParamNames = [
        'CLONE_REPOS',

        'CI_GERRIT_PROJECT',
        'CI_REFSPEC',

        'JOBS_PROJECT',
        'JOBS_REFSPEC',

        'RF_GERRIT_PROJECT',
        'RFA_REFSPEC',

        'RMM_GERRIT_PROJECT',
        'RMM_REFSPEC',

        'SPM_GERRIT_PROJECT',
        'SPM_REFSPEC',

        'TF_GERRIT_PROJECT',
        'TF_GERRIT_REFSPEC',

        'TFTF_GERRIT_PROJECT',
        'TFTF_GERRIT_REFSPEC',

        'TFUT_GERRIT_PROJECT',
        'TFUT_GERRIT_REFSPEC',

        'TF_M_EXTRAS_GERRIT_PROJECT',
        'TF_M_EXTRAS_GERRIT_REFSPEC',

        'TF_M_TESTS_GERRIT_PROJECT',
        'TF_M_TESTS_GERRIT_REFSPEC',

        'MBEDTLS_URL',

        'QA_TOOLS_REPO',
        'QA_TOOLS_BRANCH',

        'DOCKER_REGISTRY',

        'LAVA_PRIORITY',
        'LAVA_RETRIES',
    ] + gerritParamNames

    def builderParamOverrides = args.builderParams ?: [:]
    def builderParams = builderParamNames.collectEntries { name ->
        if (builderParamOverrides.containsKey(name)) {
            [(name): builderParamOverrides[name]]
        } else if (params.containsKey(name)) {
            [(name): params[name]]
        } else {
            [:]
        }
    }.findAll { _, value ->
        value != null
    }

    def ciScriptsProject = builderParams.CI_GERRIT_PROJECT
    def ciScriptsRefspec = builderParams.CI_REFSPEC

    def testNames = args.getOrDefault('testNames', (params.TESTS ?: '').tokenize())
    def testGroups = args.getOrDefault('testGroups', (params.TEST_GLOBS ?: '').tokenize())

    def builders = []

    withContainer(
        image: 'astral/uv:python3.14-alpine',

        command: 'cat',
        ttyEnabled: true,

        resourceLimitCpu: '1',
        resourceLimitMemory: '256Mi',
    ) { containerName ->
        stage('Checkout') {
            checkout gerrit(
                host: 'review.trustedfirmware.org',

                project: ciScriptsProject,
                refspec: ciScriptsRefspec,
            )
        }

        stage('Test Generation') {
            container(containerName) {
                builders = gatewayTests(
                    testNames: testNames,
                    testGroups: testGroups,
                )
            }
        }
    }

    stage('Tests') {
        parallel gatewayBuilders(
            builders: builders,
            builderJob: args.builderJob,
            builderParams: builderParams,
        )
    }
}
