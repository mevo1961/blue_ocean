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
        stage('Publish') {
          steps {
            publishHTML ([
      allowMissing: false,
      alwaysLinkToLastBuild: false,
      keepAll: true,
      reportDir: 'coverage',
      reportFiles: 'index.html',
      reportName: "RCov Report"
    ])
          }
        }
      }
    }
  }
}
