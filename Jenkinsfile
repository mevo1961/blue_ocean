pipeline {
  agent any
  stages {
    stage('Coverity_Message') {
      parallel {
        stage('Coverity_Message') {
          steps {
            echo 'Test Stage Coverity'
          }
        }
        stage('error') {
          steps {
            sh 'date'
          }
        }
      }
    }
    stage('Cleanup_Message') {
      steps {
        echo 'Cleaning up ...'
      }
    }
  }
}