pipeline {
    agent any
    stages {
        stage('Terraform fmt') {
            agent {
                docker {
                    image 'hashicorp/terraform:light'
                    args '-v "$(pwd)":/terraform'
                }
            }
            steps {
                sh '''
                    set -e
                    terraform fmt -check=true -diff=true /terraform
                '''
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
                    args '-v "$(pwd)":/terraform'
                }
            }
            steps {
                sh '''
                    cd /terraform/test
                    terraform init
                    terraform validate
                '''
            }
        }

    }
}
