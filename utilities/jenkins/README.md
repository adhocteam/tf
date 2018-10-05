## Jenkins Terraform
 This terraform file will provision an EC2 instance, install docker, and then pull the jenkins image and start jenkins on port 8080

### Possible errors
The workers generally fail to connect on initial creation. Run terraform apply again and input a different value for the number of executors. This will force the AWS EC2 instances to be recreated and they will then connect to the primary. This process can take up to ten minutes.

 Load Balancer HTTPS Listener not created -- Go into console create a new HTTPS load balancer, which uses your created adhoc.pizza SSL Certificate, and forward to jenkins-alb-target

 ### Connecting jenkins to github
 Open blue ocean 
 Add personal access token
 Select organization/repo

 ### Creating a wildcard certificate
 If a wildcard certificate does not exist one must be created

### Github OAuth
https://wiki.jenkins.io/display/JENKINS/GitHub+OAuth+Plugin#GitHubOAuthPlugin-Setup
Go to manage global security
Use github authentication
Input client ID & client secret
Under user groups give the authenticated group permission you desire, at a minimum they need read access 
  
  

