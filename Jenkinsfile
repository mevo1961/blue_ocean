pipeline {
  agent any
  stages {
    stage('Test1') {
      parallel {
        stage('Test1') {
          steps {
            sh 'echo \'Hello, world\''
          }
        }
        stage('Test2') {
          steps {
            echo '... and nothing now can ever come to any good.'
          }
        }
      }
    }
  }
}