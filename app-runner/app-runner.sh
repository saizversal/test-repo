#!/usr/bin/env bash
# =====================================
# Deploy or delete CICD IAM Role stack
# =====================================

# # First argument is environment (dev/prod/etc.)
# ENVIRONMENT="$1"
# shift # Remove environment arg from list
# # Set environment script path
# ENV_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../../../environments && pwd)"
# echo "🚨 ENV_SCRIPT_DIR resolved to: $ENV_SCRIPT_DIR"
# source "$ENV_SCRIPT_DIR/load-env.sh" "$ENVIRONMENT"

# Get current Git branch and sanitize
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null | tr '/' '-' | xargs || echo "unknown")

# # Check required variables
# REQUIRED_VARS=(PROJECT_NAME 
#                AWS_ACCOUNT_ID
#                AWS_REGION
#                OIDC_PROVIDER_NAME
#                GITHUB_REPO
#                GIT_BRANCH
#                )
# for var in "${REQUIRED_VARS[@]}"; do
#   if [ -z "${!var:-}" ]; then
#     echo "[ERROR] Required environment variable $var is not set."
#     exit 1
#   fi
# done


# Cloud Provider
CLOUD_PROVIDER=aws

# AWS Account Info
AWS_ACCOUNT_ID=599943578793
AWS_REGION=ap-south-1
GITHUB_REPO=zversal-infra

# Project Info
PROJECT_NAME=zv-github-test

# OIDC Provider Info
OIDC_PROVIDER_NAME=token.actions.githubusercontent.com

# OIDC Client and Thumbprints
CLIENT_ID=sts.amazonaws.com
GITHUBTHUBPRINTLIST_1=1c58a3a8518e8759bf075b76b750d4f2df264fcd
GITHUBTHUBPRINTLIST_2=6938fd4d98bab03faadb97b34396831e3780aea1



# Fixed role stack name
ROLE_STACK_NAME="$PROJECT_NAME-cicd-pipeline-role"
echo " Using ROLE_STACK_NAME: $ROLE_STACK_NAME"

# Command validation
usage() {
  echo "Usage: $0 [create-role|update-role|delete-role]"
  exit 1
}

if [ $# -eq 0 ]; then
  usage
fi

case "$1" in
  create-role)
    COMMAND="create"
    ;;
  update-role)
    COMMAND="update"
    ;;
  delete-role)
    COMMAND="delete"
    ;;
  *)
    usage
    ;;
esac

# Execute actions
if [ "$COMMAND" == "delete" ]; then
  echo "Deleting stack $ROLE_STACK_NAME..."
  aws cloudformation delete-stack \
    --region "$AWS_REGION" \
    --stack-name "$ROLE_STACK_NAME"

  aws cloudformation wait stack-delete-complete \
    --region "$AWS_REGION" \
    --stack-name "$ROLE_STACK_NAME"

  if [ $? -eq 0 ]; then
    echo " Stack $ROLE_STACK_NAME has been successfully deleted."
  else
    echo "[ERROR] Stack $ROLE_STACK_NAME delete failed."
    echo "Investigate: https://$AWS_REGION.console.aws.amazon.com/cloudformation/home?region=$AWS_REGION#/stacks"
  fi

else
  echo " Running $COMMAND-stack for $ROLE_STACK_NAME..."

  aws cloudformation "${COMMAND}-stack" \
    --region "$AWS_REGION" \
    --stack-name "$ROLE_STACK_NAME" \
    --template-body file://app-runner.yaml \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameters \
      ParameterKey=ProjectName,ParameterValue="$PROJECT_NAME" \
      ParameterKey=AwsAccountId,ParameterValue="$AWS_ACCOUNT_ID" \
      ParameterKey=AwsRegion,ParameterValue="$AWS_REGION" \
      ParameterKey=OidcProviderName,ParameterValue="$OIDC_PROVIDER_NAME" \
      ParameterKey=RepositoryName,ParameterValue="$GITHUB_REPO" \
      ParameterKey=GitBranch,ParameterValue="$GIT_BRANCH" \
    --tags Key=project,Value="$PROJECT_NAME"

  if [ $? -eq 0 ]; then
    echo " Stack $ROLE_STACK_NAME has been successfully $COMMAND-ed."
  else
    echo "[ERROR] Stack $COMMAND failed."
    echo " Investigate: https://$AWS_REGION.console.aws.amazon.com/cloudformation/home?region=$AWS_REGION#/stacks"
  fi
fi