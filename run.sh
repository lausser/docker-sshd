#!/bin/sh

if [ ! -d /etc/ssh/sshd_config.d ]; then
  install -d /etc/ssh/sshd_config.d
fi
echo "Include /etc/ssh/sshd_config.d/*.conf" >> /etc/ssh/sshd_config
echo "PermitRootLogin no" >> /etc/ssh/sshd_config.d/02secure.conf
echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config.d/02secure.conf
echo "AllowTcpForwarding no" >> /etc/ssh/sshd_config.d/02secure.conf
echo "PasswordAuthentication no" >> /etc/ssh/sshd_config.d/02secure.conf

ALLOWUSERS=""
for SSHD_USER in ${SSHD_USERS}; do
  if [[ "$SSHD_USER" =~ ^http ]]; then
    URL=$SSHD_USER
    USERNAME="${SSHD_USER##*/}"
    USERNAME="${USERNAME%.*}"
  elif [[ "$SSHD_USER" =~ .*:.* ]]; then
    IFS=':' read -r USERNAME PASSWORD <<< "$SSHD_USER"
  fi
  ALLOWUSERS="${ALLOWUSERS} ${USERNAME}"
  if ! getent passwd ${USERNAME} > /dev/null; then
    adduser -D -s /bin/bash ${USERNAME}
    if [ -n "$PASSWORD" ]; then
      echo "${USERNAME}:${PASSWORD}" | chpasswd
      echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config.d/02secure.conf
    fi
    install -o ${USERNAME} -g ${USERNAME} -m 700 -d /home/${USERNAME}/.ssh
    if [ -n "$URL" ]; then
      curl --silent --location --output /home/${USERNAME}/.ssh/authorized_keys "${URL}"
    fi
  fi
done
echo "AllowedUsers ${ALLOWUSERS}" >> /etc/ssh/sshd_config.d/01allowusers.conf


if [ ! -d /config/ssh/keys ]; then
  install -d /config/ssh/keys
fi

for HOST_KEY in /etc/ssh/ssh_host_*_key; do
    TYPE=$(cut -d_ -f3 <<< ${HOST_KEY##*/})
    if [ ! -f /config/ssh/keys/ssh_host_${TYPE}_key ]; then
        ssh-keygen -q -f /config/ssh/keys/ssh_host_${TYPE}_key -t ${TYPE} -N ''
    fi
    rm -f /etc/ssh/ssh_host_${TYPE}_key*
    ln -s /config/ssh/keys/ssh_host_${TYPE}_key* /etc/ssh
done

test -d /var/run/sshd || install -d /var/run/sshd

exec /usr/sbin/sshd -D -e -p ${SSHD_PORT}
