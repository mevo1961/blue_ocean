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
    stage('Publish Results') {
      parallel {
        stage('Cleanup_Message') {
          steps {
            echo 'Cleaning up ...'
          }
        }
        stage('publish Coverity results') {
          steps {
            coverityResults(connectInstance: 'escovsub1', connectView: 'mevo-test-blue_ocean', projectId: 'BTS_SC_LFS', unstable: true)
          }
        }
        stage('') {
          steps {
            sh 'publishHTML([allowMissing: true, alwaysLinkToLastBuild: false, keepAll: true, reportDir: \'./jenkins/data/COV_WORKDIR/coverity-report/\', reportFiles: \'index.html\', reportTitles: \'HTML\', reportName: \'Coverity Html\'])'
          }
        }
      }
    }
    stage('Cleanup') {
      steps {
        echo 'cleaning up ...'
      }
    }
  }
}