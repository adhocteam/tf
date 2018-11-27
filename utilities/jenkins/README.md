Jenkins will be available at: `https://jenkins.<env>.<domain_name>`

## Jenkins Terraform
 This terraform file will provision an EC2 instance, install docker, and then pull the jenkins image and start jenkins on port 8080

### Github OAuth for User Logins
https://wiki.jenkins.io/display/JENKINS/GitHub+OAuth+Plugin#GitHubOAuthPlugin-Setup
Go to manage global security
Use github authentication
Input client ID & client secret
Under user groups give the authenticated group permission you desire, at a minimum they need read access

 ### Connecting jenkins to Github Repositories
 Open blue ocean
 Add personal access token
 Select organization/repo

## Redeploying

To deploy an updated Jenkins primary node, e.g., after updating the Docker image to a new Jenkins version, use _taint_ in Terraform to mark it for redeployment.

`terraform taint -module=utilities.jenkins aws_instance.jenkins_primary`

then a subsequent `terraform apply` will pull down and deploy a new primary.

**Note:** This process will incur a brief period of downtime.