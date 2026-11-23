#!/usr/bin/env bash
# Pushes the image to AWS ECR and deploys it on an AWS EC2 server.
#
# 1. Log in to ECR and push  <registry>/<image>:<tag>
# 2. Copy deploy.sh + healthcheck.sh to the EC2 server
# 3. On EC2: log in to ECR, pull the image, run deploy.sh
#    (same health check + automatic rollback as the local deployment)
#
# Needs (provided by Jenkins credentials): AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY,
# SSH_KEY (path to the EC2 private key) and SSH_USER (e.g. ec2-user).
#
# Usage: deploy_aws.sh <image> <tag> <ecr_registry> <aws_region> <ec2_host> <container> <port>
set -euo pipefail

IMAGE="${1:?Usage: deploy_aws.sh <image> <tag> <ecr_registry> <region> <ec2_host> <container> <port>}"
TAG="${2:?missing tag}"
REGISTRY="${3:?missing ECR registry}"
REGION="${4:?missing AWS region}"
EC2_HOST="${5:?missing EC2 host}"
CONTAINER="${6:?missing container name}"
PORT="${7:?missing port}"
: "${SSH_KEY:?SSH_KEY must be set}" "${SSH_USER:?SSH_USER must be set}"

REMOTE_IMAGE="${REGISTRY}/${IMAGE}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSH_OPTS=(-i "$SSH_KEY" -o StrictHostKeyChecking=accept-new)

echo "[aws] Logging in to ECR ${REGISTRY}"
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRY"

echo "[aws] Pushing ${REMOTE_IMAGE}:${TAG}"
docker tag "${IMAGE}:${TAG}" "${REMOTE_IMAGE}:${TAG}"
docker push "${REMOTE_IMAGE}:${TAG}"

echo "[aws] Copying deployment scripts to ${EC2_HOST}"
scp "${SSH_OPTS[@]}" "${SCRIPT_DIR}/deploy.sh" "${SCRIPT_DIR}/healthcheck.sh" "${SSH_USER}@${EC2_HOST}:/tmp/"

echo "[aws] Deploying on EC2"
# The EC2 server uses its own IAM role to pull from ECR, so no keys are sent to it
ssh "${SSH_OPTS[@]}" "${SSH_USER}@${EC2_HOST}" \
    "aws ecr get-login-password --region '${REGION}' | docker login --username AWS --password-stdin '${REGISTRY}' \
     && docker pull '${REMOTE_IMAGE}:${TAG}' \
     && bash /tmp/deploy.sh '${REMOTE_IMAGE}' '${TAG}' '${CONTAINER}' '${PORT}'"

echo "[aws] SUCCESS: build ${TAG} is live on http://${EC2_HOST}:${PORT}"
