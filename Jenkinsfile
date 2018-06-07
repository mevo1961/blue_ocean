pipeline {
  agent any
  stages {
    stage('Coverity') {
      parallel {
        stage('Test6') {
          steps {
            echo 'Test Stage Coverity'
          }
        }
        stage('Coverity') {
          steps {
            sh '''cd jenkins/scripts/
./coverity_scan_all.sh y'''
          }
        }
      }
    }
    stage('Cleanup') {
      steps {
        echo 'Cleaning up ...'
      }
    }
  }
}