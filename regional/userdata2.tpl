#cloud-config

hostname: ${hostname}
manage_etc_hosts: true
preserve_hostname: false

users:
- default
- name: saras
  groups: wheel
  ssh-authorized-keys:
     - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDbetQeRA1Th9j/i0VZPdIG3Jqvs7sezK9vZ8YBcJn0NmZGldQeUx+dVofF5DPJi8oVEldFtpXWy+OcozZHCVYHbnVTARS3wPldGcbl9nwxN+eaizUX6RIREmrCSzN8J/XpH20Pu8RdiliPlWXwR+XEnYnfLjsj59SDH6okemMUPD5Rng4rJp/Xl2qbYNyuNdFs0V6BnRlM8IYi/w9d2YiNA7hy5shjyP5dWQCGmwlhqN3IUJXcyD74yvjzmau5UAudDbGJFD9Sg8PuJiFI9hMp2n9f+e8PB3YFRgqDx8jwFuxeB8FcljUjF2Ms7DVMOSqZfovMWlVd0ROcWmXqdbHF saras@Sarunass-Air"
  sudo: ['ALL=(ALL) NOPASSWD:ALL']
- name: jens
  groups: wheel
  ssh-authorized-keys:
     - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC2GOm2rzm9ZXG+fkzvsXTAi+S7aVAsh+yueInd26vWbGZdcCqJgg0vaZtwttYG+8EbkMpHGKj9aIlPhPPVcnBSVe3/DKNON3ORE6iDl5FEJujZ4kN+9Q/fCiz3tqIZzIAqFt8d59yB3r3wj9i/sBnqfX2CVx0iW3idpXLicgdwDR9PaWUa3IASJv7ejIAe9QdshdvQy5zzAA3+Oh/gJwPsFRGCY641FcXFE/ZA/hOeRZ/yLe3/pKwvVOgA2YcajO+zo4vEqj2pKqVzCruT4g4z5gE6Ld4u9jaxQPDDUX5o2dqJCmboy4J41VLg/FIb5rqE1njEMkTgM30iJhPiVVxKZ8vatlxQ2o8hBAWOOiT7Y0nkUGhhq1L08LMplJ8/2lk4PxcPp1ZO5++kFvmZLZUDPnui2RMfZ+oL6a2GHn39q5Sz5nIdTcIDtH/mIskxa2WAE9XC2i2Le52pH1o9+A/LjiLiJ4OsROeqURG3XnJqipcQWm9Bgj8EprLfGWinXqvJvPFerP6h+LFF9fGIO/kRzFYKf7HqIDBD4ub4uhGLb4gHGmdGYju1hjJ0AGdQQvop4VwhGjey2aPTXGik8hSsn2hNagXKIRKijIsDVtgYEtlsgl0c9xGkuu4WVKjjH7chY139zva4ohkdbKhymScilvd2SazQjC72IadvdJi9KQ== jens.skott@gmail.com
  sudo: ['ALL=(ALL) NOPASSWD:ALL']
- name: dan
  groups: wheel
  ssh-authorized-keys:
     - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDZYVUIrcazwdy3gDGjW1jzgH1RQQ07xOr9rH1xrr86wUpTiJzDzAutGKzv0Ih/Q719FJXe6IaHB7wczLlgbSkSWo4rJD9meRaDVx2Vjdr3mJkph0Uwuixu3jblbQFHHV+orghGP68avTYt5MBkS75VuF2Ilxlr1IL7PapeTQHu3dZ/bRSLTf1a/hRVoJxaPKV9BZyKVoDUims2Lr84QP8V2D2GHiwr7nQGUlhZA5z6H+C+onlOkREUdwee+3aRcNQJG/QmTfyXnLlVEFYgRVxM6769P5Kiq3X1qABzOb+JwSeMddFbAkblVBsKTPr8gK5eZ04xZC5pL87i5NW86uph dan@segunda.local
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
 - 'echo "license_key: 921b996f4edcf255c68c5e63f016c18c6bffecf1" | tee -a /etc/newrelic-infra.yml'
 - curl -o /etc/yum.repos.d/newrelic-infra.repo https://download.newrelic.com/infrastructure_agent/linux/yum/el/6/x86_64/newrelic-infra.repo
 - yum -q makecache -y --disablerepo='*' --enablerepo='newrelic-infra'
 - yum install newrelic-infra -y
