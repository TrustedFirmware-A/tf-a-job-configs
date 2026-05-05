def getGerrit() {
    gerrit(
        project: params.GERRIT_PROJECT,
        host: params.GERRIT_HOST ?: 'review.trustedfirmware.org',
        ref: params.GERRIT_REFSPEC,
        branch: params.GERRIT_BRANCH,
    )
}

// Builds a Jenkins GitSCM checkout for a Gerrit project.
//
// Supported checkout forms:
// - ref only: check out a branch or ref, e.g. "master" or "refs/heads/main".
// - ref and branch: check out a Gerrit change ref and also fetch its target branch.
def gerrit(Map args = [:]) {
    def checkoutRef = args.ref ?: args.branch
    def fetchRefs = [ args.ref, args.branch ].findAll { it }.unique()

    def extensions = args.extensions ?: []
    def remoteConfig = [ url: "https://${args.host}/${args.project}" ] + (
        args.credentialsId ? [ credentialsId: args.credentialsId ] : [:]
    )

    remoteConfig += [
        refspec: fetchRefs.collect { "+${it}:${localRef(it)}" }.join(' ')
    ]

    def isCloneOption = { it instanceof Map && it['$class'] == 'CloneOption' }
    def hasCloneOption = extensions.any(isCloneOption)

    extensions = extensions.collect { extension ->
        isCloneOption(extension) ? extension + [ honorRefspec: true ] : extension
    } + (hasCloneOption ? [] : [ cloneOption(honorRefspec: true) ])

    scmGit(
        branches: [[ name: localRef(checkoutRef) ]],
        userRemoteConfigs: [ remoteConfig ],
        extensions: extensions,
    )
}

def localRef(ref) {
    if (ref.startsWith('refs/heads/')) {
        return "refs/remotes/origin/${ref - 'refs/heads/'}"
    }

    "refs/remotes/origin/${ref}"
}

def gerritLabel(label) {
    def approvals = readJSON text: params.GERRIT_EVENT_UPDATED_APPROVALS

    (approvals[label].value).toInteger()
}
