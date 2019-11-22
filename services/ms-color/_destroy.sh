#!/bin/bash

if [ -z ${ENVIRONMENT} ]; then echo 'Please set ENVIRONMENT' && exit 1; fi
if [ -z ${REGION} ]; then echo "Please set REGION" && exit 1; fi

# For the sake of simplicity, get the service name by getting the folder name
SERVICE=${PWD##*/}

rm -rf .terraform

terraform init \
    -backend-config="key=${ENVIRONMENT}/${REGION}/pixel/${SERVICE}/terraform.tfstate" \
    -backend-config="bucket=pixell" && \

terraform plan -destroy \
    -out terraform.plan \
    -target="aws_lb_target_group.lb_target_group" \
    -var="environment=${ENVIRONMENT}" \
    -var="region=${REGION}" && \

while true; do
    read -p "Do you want to DELETE the infrastructure? (yn):" yn
    case $yn in
        [Yy]* ) terraform apply terraform.plan; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer y or n.";;
    esac
done