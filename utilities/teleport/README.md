## Before applying this module
Before using this module you must setup a GitHub OAuth following [their instructions](https://developer.github.com/apps/building-oauth-apps/creating-an-oauth-app/).
Use the following values substituting your variables manually:
- Homepage URL: `https://teleport-${var.name}.adhocdemo.com/`
- Callback URL: `https://teleport-${var.name}.adhocdemo.com/v1/webapi/github/callback`

and store the resulting Client ID and Secret in AWS Secrets Manager with names as follows:

- Client ID stored in `${var.name}/teleport/github_client_id`
- Secret store in `${var.name}/teleport/github_secret`

Example, if your `name` is main, then the values would be:

- Homepage URL: `https://teleport-main.adhocdemo.com/`
- Callback URL: `https://teleport-main.adhocdemo.com/v1/webapi/github/callback`
- Client ID stored in `main/teleport/github_client_id`
- Secret store in `main/teleport/github_secret`

## Using the bastion once applied

### Via the webui

Visit https://teleport-${var.name}.adhocdemo.com/ and using the login with Github button. Approve the oauth request for the app on github. Then select the node to ssh into from the webui.

### Via the command line

You can download the client from [Gravitational](https://gravitational.com/teleport/download/) but be sure to use version 2.7.4 or later. You can also use direct links for [Linux](https://get.gravitational.com/teleport-v2.7.4-linux-amd64-bin.tar.gz) or [Mac](https://get.gravitational.com/teleport-v2.7.4-darwin-amd64-bin.tar.gz) to get 2.7.4 always.

Decompress and put the `tsh` someplace on your `$PATH`. There's an included `install` script that'll handle that but will also copy over the unneeded teleport and tctl binaries.

**Always do**
Login using `tsh login --proxy=teleport-${var.name}.adhocdemo.com:443` which should open a browser window and complete the login via GitHub automatically

#### Then either:

##### Use tsh

Find possible hosts using `tsh ls` and connect using `tsh ssh ec2-user@<node name>` or `tsh ssh ec2-user@<target private ip>`

##### Use ssh

Setup SSH proxying in your `$HOME/.ssh/config` with the snippet after replacing the variables :

```
#
Host teleport
    HostName teleport-${var.name}.adhocdemo.com
    Port 3023

Host 10.1.*
    HostName %h
    User ec2-user
    Port 3022
    ProxyCommand ssh -p 3023 %r@teleport -s proxy:%h:%p
```
Once you've issued the login, the certificate will be loaded into your ssh-agent automatically (assuming the agent is running). Make sure you don't have more than 3-4 other identities loaded otherwise the SSH host may reject the connect for too many failed attempts as the SSH agent tries each in turn. Check for the certificate by running `ssh-add -L | grep teleport`

Then just `ssh <target private ip>`

##### Use Ansible

Set up the SSH support per the above and make sure the inventory is using private IP addresses. The it should work out of the box. More info in the upstream [admin manual](https://gravitational.com/teleport/docs/admin-guide/#integrating-with-ansible).


### Using the emergency jumpbox

Add the following to your `$HOME/.ssh/config` file, substituting the items in `<>` with your values

```
Host jumpbox
  HostName      <jumpbox-public-ip>
  User          ec2-user
  IdentityFile  ~/.ssh/<private-key>

Host target
  HostName      <target-private-ip>
  User          ec2-user
  IdentityFile  ~/.ssh/<private-key>
  ProxyJump     jumpbox
```

Then `ssh target`

