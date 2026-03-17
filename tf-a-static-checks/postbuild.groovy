def project = manager.getEnvVariable('GERRIT_PROJECT')
def logPath = "${project}/static-checks.log"

def html = (manager.getResult() == 'SUCCESS')
    ? '<h1 style="color: green;">No errors detected</h1>'
    : '<h1 style="color: red;">Errors detected</h1>'

try {
    def artifacts = manager.build
        .getArtifactManager()
        .root()

    def log = artifacts
        .child(project)
        .child('static-checks.log')

    html += "<pre><code>${log.open().text}</code></pre>"
} catch (IOException e) {
    html += "<strong>Could not read static checks log: <code>${logPath}</code></strong>"
    manager.listener.logger.println("Could not read static checks log (`${logPath}`): ${e.message}")
}

manager.createSummary('clipboard.gif').appendText(html, false)
