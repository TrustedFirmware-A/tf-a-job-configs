def icon = 'symbol-git-merge-outline plugin-ionicons-api'

manager.createSummary(icon).appendText((
    manager.build.artifactManager
        .root().child('report.html')
        .open().text
), false)
