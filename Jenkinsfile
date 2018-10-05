pipeline {
    agent any
    stages {
        stage('Terraform fmt') {
            steps {
                sh '''
                    set -e
                    docker run -v "$(pwd)":/terraform hashicorp/terraform:light fmt -check=true /terraform
                '''
            }
        }

        stage('Terraform linting') {
            steps {
                sh '''
                    non_camel=$(find . -name "*.tf" -exec grep -l "^[a-z].*-" {} \;)
                    if [[ ! -z "$non_camel" ]]; then
                        echo "Resources should be camel_case and not use hyphens:"
                        for f in "$non_camel"; do
                            grep -n "^[a-z].*-" $f
                        done
                        exit 1
                    fi
                '''
            }
        }
    }
}
