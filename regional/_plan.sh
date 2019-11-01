#!/bin/bash

if [ -z ${ENVIRONMENT} ]; then echo 'Please set ENVIRONMENT' && exit 1; fi
if [ -z ${REGION} ]; then echo "Please set REGION" && exit 1; fi

PROJECT=resume-points

rm -rf .terraform

terraform init \
    -backend-config="key=${ENVIRONMENT}/${REGION}/pixel/terraform.tfstate" \
    -backend-config="bucket=pixell" && \

terraform plan \
    -out terraform.plan \
    -var="environment=${ENVIRONMENT}" \
    -var="region=${REGION}" && \

while true; do
    read -p "Do you want to apply the terraform configuration? (yn):" yn
    case $yn in
        [Yy]* ) terraform apply terraform.plan; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer y or n.";;
    esac
done