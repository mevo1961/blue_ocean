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
            sh '''# cd jenkins/scripts/
# ./coverity_scan_all.sh y'''
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
            coverityResults(connectInstance: 'escovsub1', connectView: 'Outstanding Defects - AirScale5G - DDAL', projectId: 'BTS_SC_LFS', unstable: true)
          }
        }
      }
    }
  }
}