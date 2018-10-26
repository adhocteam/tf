### Using the Jumpbox

Add the following to your `$HOME/.ssh/config` file, substituting the items in `<>` with your values

```
Host jumpbox
  HostName      jumpbox.<env>.<domain_name>
  User          ec2-user
  IdentityFile  ~/.ssh/<private_key>

Host target
  HostName      <target-private-ip>
  User          ec2-user
  IdentityFile  ~/.ssh/<private_key>
  ProxyJump     jumpbox
```

Then `ssh target`

### Key Pair

By default, this will use `infrastructure` as the key pair. This can be overridden by setting the `key_pair`
variable. You will have to setup the key pair yourself first in AWS.

