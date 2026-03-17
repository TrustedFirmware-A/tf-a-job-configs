def lava = manager.getLogMatcher('LAVA URL: (?<url>[^ ]+) LAVA JOB ID: (?<id>\\d+)')
def tux = manager.getLogMatcher('TuxSuite test ID: (?<id>[A-Za-z0-9]+)')

if (lava != null) {
    def id = lava.group('id')
    def url = lava.group('url')

    def icon = 'symbol-pulse-outline plugin-ionicons-api'

    manager.createSummary(icon).appendText("""
        <p>LAVA validation results: <a href="${url}">${id}</a></p>
    """, false)
}

if (tux != null) {
    def group = manager.getEnvVariable('TUXSUITE_GROUP')
    def project = manager.getEnvVariable('TUXSUITE_PROJECT')

    assert group
    assert project

    def id = tux.group('id')
    def url = "https://tuxapi.tuxsuite.com/v1/groups/${group}/projects/${project}/tests/${id}"

    def icon = 'symbol-pulse-outline plugin-ionicons-api'

    manager.createSummary(icon).appendText("""
        <p>TuxSuite validation results: <a href="${url}">${id}</a></p>
    """, false)
}
