pipeline {
    agent any
    stages {
        stage('Test') {
            steps {
                sh '''
                    set -e
                    docker run -v "$(pwd)":/terraform hashicorp/terraform:light fmt -check=true
                '''
            }
        }
    }
}
