def coverageMatcher = manager.getLogMatcher('Files coverage: (?<coverage>[\\d]+%)')
def coverage = coverageMatcher?.group('coverage') ?: 'missing coverage data'

if (coverage != '100%') {
    manager.addWarningBadge("Incomplete file coverage (${coverage})")
    manager.buildFailure()
}

def log = manager.build
    .getArtifactManager()
    .root().child('trusted-firmware-a/tf_coverage.log')

def icon = 'symbol-clipboard-outline plugin-ionicons-api'

manager.createSummary(icon).appendText("""
    <pre><code>${log.open().text}</code></pre>
""", false)
