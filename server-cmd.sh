#!/bin/bash

export IMAGE_NAME=$1

# Login to Docker Hub so you can pull the private image (if applicable)
# If the repo is public, you can skip the login here.

docker-compose pull
docker-compose up -d

# Optional: Remove old, unused images to save disk space on the EC2
docker image prune -f
