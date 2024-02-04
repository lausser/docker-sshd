# docker-sshd
A container which runs sshd

## Environment variables

- SSHD_PORT  
  The port where the ssh daemon should listen. Default is 22.
- SSHD_USERS  
  A list of users separated by spaces. Supported formats are:
  - A url like *https://github.com/lausser.keys*, where the username will be *lausser* and the downloaded file will be saved to *~lausser/.ssh/authorized_keys*
  - A string like *username:password*  
  If SSHD_USERS is empty, a random username with a random password will be created and written to the containers stderr.

## Persistent hostkeys
You can mount a folder to /config/ssh/keys and the container will save it's host keys there. Next time you run a container and mount this folder on /config/ssh/keys, it will use the same host keys again.
