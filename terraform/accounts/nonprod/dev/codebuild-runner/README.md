# CodeBuild Github Action Runner

## Setup

You need to have a repo and repo access for this to execute correctly.  See your existing codestar connection in github, settings, application to verify.

For standing it up, it can seem fine, but when job executes you may have access issues.  This will either be resources you forgot to add to the role like S3, Lambda, EKS, ECS, etc.  All the nitty gritty `Action:` stuff on `Resource:` policy fun.

Remember if your CodeBuild needs access to VPC with private Subnets you need to also give it that permission.
This can create a chicken/egg situation but comments in common.hcl for more.

