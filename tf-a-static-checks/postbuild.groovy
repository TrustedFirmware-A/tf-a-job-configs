def logPath = manager.getEnvVariable('TF_A_STATIC_CHECKS_LOG_PATH')
def html = (logPath && (manager.getResult() == 'SUCCESS'))
    ? '<h1 style="color: green;">No errors detected</h1>'
    : '<h1 style="color: red;">Errors detected</h1>'

if (logPath) {
    try {
        def log = manager.build
            .getArtifactManager()
            .root().child(logPath)

        html += "<pre><code>${log.open().text}</code></pre>"
    } catch (IOException e) {
        html += "<p><strong style=\"color: red;\">Internal error:</strong> could not fetch log artifact: <code>${logPath}</code></p>"
        manager.listener.logger.println("Could not read log artifact (`${logPath}`): ${e.message}")
    }
} else {
    html += '<p><strong style="color: red;">Internal error:</strong> no log artifact found!</p>'

    manager.listener.logger.println("Could not read log artifact: ${logPath}")
    manager.buildFailure()
}

manager.createSummary('clipboard.gif').appendText(html, false)
