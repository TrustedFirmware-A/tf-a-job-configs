def htmlLinks = ''

def lavaMatcher = manager.getLogMatcher('LAVA URL: (?<url>[^ ]+) LAVA JOB ID: (?<id>\\d+)')
def lavaMatches = lavaMatcher?.matches()

if (lavaMatches) {
    def id = lavaMatcher.group('id')
    def url = lavaMatcher.group('url')

    htmlLinks += "<li><strong>LAVA Job:</strong> <a href=\"${url}\">${id}</a> (<a href=\"artifact/lava.log\">log</a>)</li>"

    def resultMatcher = manager.getLogMatcher('LAVA JOB RESULT: (?<result>\\d+)')
    def resultMatches = resultMatcher?.matches()

    if (!resultMatches || (resultMatches.group('result') != '0')) {
        manager.buildFailure()
    }
}

def tuxMatcher = manager.getLogMatcher('TuxSuite test ID: (?<id>[A-Za-z0-9]+)')
def tuxMatches = tuxMatcher?.matches()

if (tuxMatches) {
    def id = tuxMatcher.group('id')

    def abbrLen = 19 // Maximum ID length before we abbreviate it
    def abbrId = (id.length() > 19) ? ('...' + id.substring(19)) : id

    def group = manager.getEnvVariable('TUXSUITE_GROUP')
    def project = manager.getEnvVariable('TUXSUITE_PROJECT')

    if (group && project) {
        def jobUrl = "https://tuxapi.tuxsuite.com/v1/groups/${group}/projects/${project}/tests/${id}"
        def logUrl = "https://storage.tuxsuite.com/public/${group}/${project}/tests/${id}/lava-logs.html"

        htmlLinks += "<li><strong>TuxSuite results:</strong> <a href=\"${jobUrl}\">${abbrId}</a> (<a href=\"${logUrl}\">log</a>)</li>"

        def resultMatcher = manager.getLogMatcher('TuxSuite test result: (?<result>\\d+)')
        def resultMatches = resultMatcher?.matches()

        if (!resultMatches || (resultMatcher.group('result') != '0')) {
            manager.buildFailure()
        }
    } else {
        htmlLinks += '<li><strong>TuxSuite results:</strong> <strong style="color: red;">(missing TuxSuite group/project metadata)</strong></li>'

        manager.buildFailure()
    }
}

if (htmlLinks) {
    def color = (manager.getResult() == 'SUCCESS')
        ? 'green' : 'red'

    manager.createSummary('clipboard.gif').appendText("""
        <h1 style="color: ${color};">External test summary</h1>
        <ul>${htmlLinks}</ul>
    """, false)
}
