# EKS Fargate Codebuild

Sets up a EKS Fargate Cluster.
Sets up a Codebuild runner for github actions.

## Python Script wrapper for Terraform/Terragrunt

### Setup CodeBuild Runner for Github (CI / CD)

Benefit here is its a self-hosted runner in AWS and github Actions will execute your Pipeline on it.

Pre-requisite: Have your Github Repository setup.  It will push a webhook to it via CodeStar Connection.

### Init

`python terraform/scripts/tg.py -a nonprod -e dev -f codebuild-runner -c init`

### Validate

`python terraform/scripts/tg.py -a nonprod -e dev -f codebuild-runner -c validate`

### Plan

`python terraform/scripts/tg.py -a nonprod -e dev -f codebuild-runner -c plan`

### Apply

`python terraform/scripts/tg.py -a nonprod -e dev -f codebuild-runner -c apply`