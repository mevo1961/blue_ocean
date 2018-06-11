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
        stage('') {
          steps {
            coverityResults(connectInstance: 'escovsub1', connectView: 'master--ddal--x86_64-pc-linux-gnu', projectId: 'BTS_SC_LFS', failPipeline: true)
          }
        }
      }
    }
  }
}