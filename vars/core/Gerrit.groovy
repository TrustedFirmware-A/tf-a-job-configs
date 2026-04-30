def getGerrit() {
    gerrit()
}

def gerrit(Map args = [:]) {
    def useParamDefaults = args.isEmpty()

    def project = args.getOrDefault('project', params.GERRIT_PROJECT)
    def host = params.GERRIT_HOST

    def remote = args.getOrDefault('remote', host ? "https://${host}/${project}" : null)
    def refspec = args.getOrDefault('refspec', useParamDefaults ? params.GERRIT_REFSPEC : null)
    def checkoutRef = args.getOrDefault('branch', useParamDefaults ? params.GERRIT_BRANCH : null)

    def extensions = args.extensions ?: []
    def remoteConfig = [ url: remote ] + (
        args.credentialsId ? [ credentialsId: args.credentialsId ] : [:]
    )

    if (refspec) {
        def fetchRef = refspec.replaceFirst(/^\+/, '')

        checkoutRef = "refs/remotes/origin/${fetchRef}"
        remoteConfig += [ refspec: "+${fetchRef}:refs/remotes/origin/${fetchRef}" ]

        def isCloneOption = { it instanceof Map && it['$class'] == 'CloneOption' }
        def hasCloneOption = extensions.any(isCloneOption)

        extensions = extensions.collect { extension ->
            isCloneOption(extension) ? extension + [ honorRefspec: true ] : extension
        } + (hasCloneOption ? [] : [ cloneOption(honorRefspec: true) ])
    }

    scmGit(
        branches: [[ name: checkoutRef ]],
        userRemoteConfigs: [ remoteConfig ],
        extensions: extensions,
    )
}
