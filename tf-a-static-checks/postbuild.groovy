def logPath = manager
    .getEnvVariable('TF_A_STATIC_CHECKS_LOG_PATH')

def log = manager.build
    .getArtifactManager()
    .root().child(logPath)

def icon = 'symbol-clipboard-outline plugin-ionicons-api'

manager.createSummary(icon).appendText("""
    <pre><code>${log.open().text}</code></pre>
""", false)
