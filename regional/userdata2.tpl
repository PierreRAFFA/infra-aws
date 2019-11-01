#cloud-config

hostname: ${hostname}
manage_etc_hosts: true
preserve_hostname: false

users:
- default
- name: pierre
  groups: wheel
  ssh-authorized-keys:
     - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDIbXnqhJgQU5o5SJ7L2f72JvrMPagkLmn/OfaOCz5f/nXEfYQx8Ciy3gZzbq4tBy6pxbwEHJPuleO0Cx64ldX1neXnXQYBCXB9DNhK65X0DZMomPibPSAVZtwdj7bnh4vxlnOzUJW2F2N/lrbROr6prgHghM8VfOK1ryRN+L4w1+ZF1E8BujtM5sVEiwUL+wdskMRuZ9/4oNgR3R1MmW32ghxrCZrRTxWvKuyHvpFclizLOhYN1caQ6fr//s6LGl9XFEJ91YLl2+4j9YRZYWxBw0oIarA9bduq48o68xb83g+2OXBWed4vPu9zgBvpmnDGIWthKdDtvzM8CFFT9VLSfdDtqa9Wg0jX3bRAfENc9Bn69hWPeZzLNC9HoCkiewPl4pn/4jqLKscu3RxULdAymNEdT1lMueNvjABS5mBWklzRNTbF3V0fBP0xSyLYoXQ1lLU1U7Qz7k7X4RHkxhE6X57yPUzDIxVMX2Yen0QyLBFN2Tf7ZNNkgbjMU/q4FHwaGfNz35Dy8vFvNwvWnghCetPXDwtUGHAkpoNs6fegSoUBy05Fy5yjEsuPcCSoLXi0kOUPw3NEaVmCdkSvj5LY1UO/7a3nPht/UNydrq6uIwnlB+YsGy5p5V9AWlpfTypQInEakv+9uvff8S3kzgiADNtWFErTt4eNS1NlBmJ2xw== pierre.raffa@ldn-pierre.local
  sudo: ['ALL=(ALL) NOPASSWD:ALL']

write_files:
  - content: |
      root hard nofile ${nofile_limit}
      root soft nofile ${nofile_limit}
      * hard nofile ${nofile_limit}
      * soft nofile ${nofile_limit}
    path: /etc/security/limits.d/00-nofile.conf
    owner: root:root
    permissions: '0644'

runcmd:
 - chmod 755 /var && chmod 755 /var/{log,lib,run}
 - echo ECS_CLUSTER=${ecs_name} >> /etc/ecs/ecs.config
 - echo ECS_ENABLE_TASK_IAM_ROLE=true >> /etc/ecs/ecs.config
 - 'echo "license_key: 0000000000000" | tee -a /etc/newrelic-infra.yml'
 - curl -o /etc/yum.repos.d/newrelic-infra.repo https://download.newrelic.com/infrastructure_agent/linux/yum/el/6/x86_64/newrelic-infra.repo
 - yum -q makecache -y --disablerepo='*' --enablerepo='newrelic-infra'
 - yum install newrelic-infra -y
