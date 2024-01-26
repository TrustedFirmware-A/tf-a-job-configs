import hudson.model.*

def getUpstreamRoot(cause) {
    causes = cause.getUpstreamCauses()
    if (causes.size() > 0) {
        if (causes[0] instanceof hudson.model.Cause.UpstreamCause) {
            return getUpstreamRoot(causes[0])
        }
    }
    return cause
}

def description = ""
def rootUrl = manager.hudson.getRootUrl()

// Add a LAVA job link to the description
def matcher = manager.getLogMatcher("LAVA URL: (?<url>.*?) LAVA JOB ID: (?<jobid>\\d+)")
if (matcher?.matches()) {
    def testJobId = matcher.group('jobid')
    def testJobUrl = matcher.group('url')
    description += "LAVA Job Id: <a href='${testJobUrl}'>${testJobId}</a>\n"

    def lavaLogUrl = "${rootUrl}${manager.build.url}artifact/lava.log"
    description += " | <a href='${lavaLogUrl}'>log</a>\n"

    // Verify LAVA jobs results, all tests must pass, otherwise turn build into FAILED
    def testMatcher = manager.getLogMatcher("LAVA JOB RESULT: (?<result>\\d+)")
    if (testMatcher?.matches()) {
        def testJobSuiteResult = testMatcher.group('result')
        // result = 1 means lava job fails
        if (testJobSuiteResult == "1") {
            manager.buildFailure()
        }
    }
}

// Add a TuxSuite job link to the description
matcher = manager.getLogMatcher("TuxSuite test ID: (?<tuxid>[A-Za-z0-9]+)")
if (matcher?.matches()) {
    def tuxId = matcher.group('tuxid')
    def abbrTuxId = "..." + tuxId.substring(19)
    description += "Tux Id: <a href='https://tuxapi.tuxsuite.com/v1/groups/tfc/projects/ci/tests/${tuxId}'>${abbrTuxId}</a>\n"
    description += " | <a href='https://storage.tuxsuite.com/public/tfc/ci/tests/${tuxId}/lava-logs.html'>log</a>\n"

    // Verify test job results set build status as FAILED if needed
    def testMatcher = manager.getLogMatcher("TuxSuite test result: (?<result>\\d+)")
    if (testMatcher?.matches()) {
        def testJobSuiteResult = testMatcher.group('result')
        // result = 1 means job fails
        if (testJobSuiteResult == "1") {
            manager.buildFailure()
        }
    }
}


def causes = manager.build.getAction(hudson.model.CauseAction.class).getCauses()
if (causes[0] instanceof hudson.model.Cause.UpstreamCause) {
    def rootCause = getUpstreamRoot(causes[0])
    def upstreamBuild = rootCause.upstreamBuild
    def upstreamProject = rootCause.upstreamProject
    def jobName = upstreamProject
    def jobConfiguration = upstreamProject
    def jobUrl = "${rootUrl}job/${upstreamProject}/${upstreamBuild}"
    description += "<br>Top build: <a href='${jobUrl}'>${upstreamProject} #${upstreamBuild}</a>"
}

// Set accumulated description
manager.build.setDescription(description)
