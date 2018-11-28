pipeline {
    agent {
        label 'general'
    }

    stages {
        stage('Terraform fmt') {
            agent {
                docker {
                    image 'hashicorp/terraform:light'
                    args '-w $WORKSPACE --entrypoint=""'
                }
            }
            steps {
                sh 'terraform fmt -check=true -diff=true'
            }
        }

        stage('Terraform linting') {
            steps {
                sh 'scripts/lint.sh'
            }
        }

        stage('Terraform validation') {
            agent {
                docker {
                    image 'hashicorp/terraform:light'
                    args '-w $WORKSPACE --entrypoint=""'
                }
            }
            steps {
                sh '''
                    cd test
                    terraform init
                    terraform validate
                '''
            }
        }
    }

    post {
        always {
            deleteDir()
            cleanWs()
        }
    }
}
