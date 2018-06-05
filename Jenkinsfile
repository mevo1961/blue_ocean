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
        stage('Test3') {
          steps {
            echo 'Everything will be good in the end. If it\'s not good, it\'s not the end!'
          }
        }
      }
    }
    stage('Test4') {
      parallel {
        stage('Test4') {
          steps {
            echo 'For all that we see or seem, is just a dream within a dream ...'
          }
        }
        stage('Test5') {
          steps {
            echo 'If anything can go wrong, it will ...'
          }
        }
      }
    }
  }
}