pipeline {
    agent {
        label 'website'
    }

    stages {
        stage('Terraform fmt') {
            agent {
                docker {
                    image 'hashicorp/terraform:light'
                    args '-v ${PWD}:/terraform -w /terraform --entrypoint=""'
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
                    args '-v ${PWD}:/terraform -w /terraform --entrypoint=""'
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
