# AD Hoc Base AMI

This AMI is our basic starting point for deploying services. It's designed to interoprate with our [Terraform modules](https://github.com/adhocteam/tf).

## Contents

It is based off of the latest [Amazon Linux 2 AMI](https://aws.amazon.com/amazon-linux-2/) for the US-East-1 region.

The `base.json` Packer template uses Ansible to apply the `playbooks/base.yml` to provision an AMI with the following services installed and running:

- Docker daemon
- Teleport SSH proxy

## Build

To build a new AMI: `packer build base.json`

## Use

### Module

Our [plain instnace module](https://github.com/adhocteam/tf/tree/master/plain_instance) sets up the AMI and
allows further configuration via Ansible:

```hcl

```


### Directly
To use the AMI, pull in the latest AMI version in Terraform

```hcl

```

And then provide the cluster secret for the SSH agent

```hcl

```

If the cluster secret isn't provided, then SSH is still enabled for access directly or via a jumpbox.