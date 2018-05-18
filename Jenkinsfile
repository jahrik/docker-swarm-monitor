#!/usr/bin/env groovy

node('master') {

    try {

        stage('build') {
            // Clean workspace
            deleteDir()
            // Checkout the app at the given commit sha from the webhook
            checkout scm
        }

        stage('test') {
            // Run any testing suites
            sh "echo 'WE ARE TESTING'"
        }

        stage('deploy') {
            sh "echo 'WE ARE DEPLOYING'"
            wrap([$class: 'AnsiColorBuildWrapper', colorMapName: "xterm"]) {
                ansibleTower(
                    towerServer: 'shredder',
                    jobTemplate: 'monitor',
                    importTowerLogs: true,
                    inventory: '',
                    jobTags: '',
                    limit: '',
                    removeColor: false,
                    verbose: true,
                    credential: '',
                    extraVars: '''---
                      test: "test"'''
                )
            }
        }

    } catch(error) {
        throw error

    } finally {
        // Any cleanup operations needed, whether we hit an error or not

    }
}
