# Terraform Foundation

This is an opinionated setup for a basic 3-tier app in AWS from the VPC on up. Our primary goal is speed of setup over flexibility. Therefore, we try to restrict the number of variables per modules to a reasonable minimum.

## Examples

- [VAOS Technical Demo](https://github.com/adhocteam/vaos)

## Sources of inspiration

The approach taken here was influenced by reviewing the following sources (some private to Ad Hoc)

External Prior Art:
- [Collection of Terraform AWS modules supported by the community](https://github.com/terraform-aws-modules/)
- [18f Cloud.gov Provisioning](https://github.com/18F/cg-provision)
- [GOV.UK Terraform resources](https://github.com/alphagov/govuk-aws/tree/master/terraform)
- [Segment's Stack](https://github.com/segmentio/stack)

Ad Hoc's Work:
- [Soapbox's Platform Setup](https://github.com/adhocteam/soapbox/tree/master/ops/aws/terraform)
- [ACO API Challenge](https://github.com/adhocteam/aco-api-rfq)
- [QPP Foundational Challenge](https://github.com/adhocteam/qpp-infra-challenge)
- [USCIS RFDS RFI Response](https://github.com/adhocteam/uscis_rfi_response)

## AWS Provider version

The modules rely on [implicit provider inheritance](https://www.terraform.io/docs/modules/usage.html#implicit-provider-inheritance). We suggest `version = "~> 1.52"` or higher. The database module requires PostgreSQL logging features enabled in that release.