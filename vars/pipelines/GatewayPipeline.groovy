def parseTopicRefspec(String queryOutput) {
    def jsonLines = queryOutput
        .readLines()
        .collect { it.trim() }
        .findAll { it }

    if (!jsonLines) {
        throw new IllegalStateException(
            'No input received from Gerrit query.'
        )
    }

    def responses = readJSON(
        text: "[${jsonLines.join(',')}]",
        returnPojo: true,
    )

    // Gerrit appends a statistics record after the change records.
    def changes = responses.findAll {
        it.type != 'stats'
    }

    if (!changes) {
        return null
    }

    if (changes.size() == 1) {
        def refspec = changes.first().currentPatchSet?.ref

        if (!refspec) {
            throw new IllegalStateException(
                'The Gerrit change does not contain currentPatchSet.ref.'
            )
        }

        return refspec.toString()
    }

    return findTopicTipRefspec(changes)
}

def findTopicTipRefspec(List changes) {
    def project = changes.first().project
    def topic = changes.first().topic

    def currentPatchSets = changes.collect { change ->
        def patchSet = change.currentPatchSet

        if (!patchSet) {
            throw new IllegalStateException(
                "A change in topic '${topic}' for project '${project}' " +
                'does not contain a current patch set.'
            )
        }

        if (!patchSet.revision) {
            throw new IllegalStateException(
                "A current patch set in topic '${topic}' for project '${project}' " +
                'does not contain a revision.'
            )
        }

        patchSet
    }

    def parentRevisions = currentPatchSets.collect { patchSet ->
        def parents = patchSet.parents

        if (parents?.size() != 1) {
            throw new IllegalStateException(
                "Patch set '${patchSet.revision}' in topic '${topic}' " +
                "for project '${project}' must have exactly one parent."
            )
        }

        parents.first().toString()
    } as Set

    def tips = currentPatchSets.findAll { patchSet ->
        !parentRevisions.contains(patchSet.revision.toString())
    }

    if (tips.size() > 1) {
        throw new IllegalStateException(
            "${topic} in ${project} has no unique tip commit."
        )
    }

    if (!tips) {
        throw new IllegalStateException(
            "No tip commit found for ${topic} in ${project}."
        )
    }

    def refspec = tips.first().ref

    if (!refspec) {
        throw new IllegalStateException(
            "The tip commit for ${topic} in ${project} has no refspec."
        )
    }

    return refspec.toString()
}

def gatewayTests(Map args) {
    def tests = args.testNames

    if (args.testGroups) {
        dir('tf-a-toolbox') {
            def includes = args.testGroups.collect {
                "--include ${shellQuote(it)}"
            }.join(' ')

            def excludes = (args.testGroupsExclude ?: []).collect {
                "--exclude ${shellQuote(it)}"
            }.join(' ')

            def filters = [includes, excludes].findAll().join(' ')

            def output = sh(
                script: "uv run --no-dev --extra cli -- tf-a-toolbox matrix groups ${filters}",
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
                    value instanceof Boolean
                        ? booleanParam(name: key.toString(), value: value)
                        : string(name: key.toString(), value: value.toString())
                }
        }]
    }
}

def recordGatewayCoverage(Map args) {
    def builderResults = args.builderResults

    checkout gerrit(
        host: 'review.trustedfirmware.org',
        project: params.GERRIT_PROJECT,
        ref: params.GERRIT_REFSPEC,
    )

    builderResults.each { _, run ->
        copyArtifacts(
            projectName: run.fullProjectName,
            selector: specific(run.number.toString()),
            filter: 'trace_report/coverage.info',
            target: "coverage/${run.externalizableId}",
            optional: true,
        )
    }

    recordCoverage(
        sourceDirectories: [[path: '.']],
        sourceCodeRetention: 'EVERY_BUILD',

        tools: [[
            parser: 'LCOV',
            pattern: 'coverage/**/trace_report/coverage.info'
        ]],
    )
}

def resolveTopicRefspec(String project, String defaultRefspec) {
    if (!params.GERRIT_TOPIC) {
        return defaultRefspec
    }

    if (params.GERRIT_PROJECT == project) {
        return defaultRefspec
    }

    def query = [
        'gerrit query',
        '--format=JSON',
        '--no-limit',
        '--current-patch-set',
        'status:open',
        shellQuote("project:${project}".toString()),
        shellQuote("topic:{${params.GERRIT_TOPIC}}".toString()),
    ].join(' ')

    def host = (params.GERRIT_HOST ?: 'review.trustedfirmware.org').replace('https://', '')
    def queryOutput
    withEnv(["GERRIT_QUERY_HOST=${host}", "GERRIT_QUERY_COMMAND=${query}"]) {
        withCredentials([sshUserPrivateKey(
            credentialsId: 'TFA_CI_BOT_USER_SSH_KEY',
            keyFileVariable: 'CI_BOT_KEY',
            usernameVariable: 'CI_BOT_USERNAME',
        )]) {
            queryOutput = sh(
                script: 'ssh -o UserKnownHostsFile=/dev/null ' +
                    '-o StrictHostKeyChecking=no -o PubkeyAcceptedKeyTypes=+ssh-rsa ' +
                    '-p 29418 -i "$CI_BOT_KEY" ' +
                    '"$CI_BOT_USERNAME@$GERRIT_QUERY_HOST" "$GERRIT_QUERY_COMMAND"',
                returnStdout: true,
            ).trim()
        }
    }

    def refspec = parseTopicRefspec(queryOutput)

    if (refspec == null) {
        echo """
            No open topic-linked change found for project '${project}'.
            Using default refspec '${defaultRefspec}'.
        """.stripIndent().trim()

        return defaultRefspec
    }

    return refspec
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

        'TF_M_EXTRAS_GERRIT_PROJECT',
        'TF_M_EXTRAS_GERRIT_REFSPEC',

        'TF_M_TESTS_GERRIT_PROJECT',
        'TF_M_TESTS_GERRIT_REFSPEC',

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

    def testNames = args.getOrDefault('testNames', (params.TESTS ?: '').tokenize())
    def testGroups = args.getOrDefault('testGroups', (params.TEST_GLOBS ?: '').tokenize())
    def testGroupsExclude = args.getOrDefault('testGroupsExclude', (params.TEST_GLOBS_EXCLUDE ?: '').tokenize())

    def builders = []

    withContainer(
        image: 'astral/uv:python3.14-alpine',

        command: 'cat',
        ttyEnabled: true,

        resourceLimitCpu: '1',
        resourceLimitMemory: '256Mi',
    ) { containerName ->
        stage('Checkout') {
            def ciScriptsRefspec = args.containsKey('ciScriptsRefspec')
                ? args.ciScriptsRefspec
                : resolveTopicRefspec(ciScriptsProject, builderParams.CI_REFSPEC)

            builderParams.CI_REFSPEC = ciScriptsRefspec
            builderParams.CI_REFSPEC_SELECTED = true

            checkout gerrit(
                host: 'review.trustedfirmware.org',

                project: ciScriptsProject,
                ref: ciScriptsRefspec,
            )
        }

        stage('Test Generation') {
            container(containerName) {
                builders = gatewayTests(
                    testNames: testNames,
                    testGroups: testGroups,
                    testGroupsExclude: testGroupsExclude,
                )
            }
        }
    }

    stage('Tests') {
        def builderResults = parallel gatewayBuilders(
            builders: builders,
            builderJob: args.builderJob,
            builderParams: builderParams,
        )

        node('docker-amd64-tf-a-jammy') {
            recordGatewayCoverage(
                builderResults: builderResults,
            )
        }
    }
}
