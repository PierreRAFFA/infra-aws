#cloud-config

hostname: ${hostname}
manage_etc_hosts: true
preserve_hostname: false

users:
- default
- name: pierre
  groups: wheel
  ssh-authorized-keys:
     - ssh-rsa
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
