pipeline {
  agent any
  stages {
    stage('Coverity') {
      parallel {
        stage('Coverity_Message') {
          steps {
            echo 'Test Stage Coverity'
          }
        }
        stage('Coverity_run') {
          steps {
            sh '''cd jenkins/scripts/
./coverity_scan_all.sh y'''
          }
        }
      }
    }
    stage('Cleanup_Message') {
      parallel {
        stage('Cleanup_Message') {
          steps {
            echo 'Cleaning up ...'
          }
        }
        stage('error') {
          steps {
            sh '''publishHTML(target: [
            allowMissing: true,
            alwaysLinkToLastBuild: true,
            keepAll: true,
            reportDir: \'./jenkins/data/COV_WORKDIR/coverity-results/src\',
            reportFiles: \'index.html\',
            reportTitles: "Coverity Report",
            reportName: "Coverity Report"
          ])'''
            }
          }
        }
      }
    }
  }