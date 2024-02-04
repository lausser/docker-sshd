#!/bin/bash

SSHD_PORT="${SSHD_PORT:-22}"
if [ -z "$SSHD_USERS" ]; then
  SSHD_USERS="$(shuf -n1 /usr/share/cracklib/cracklib-words):$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)"
  echo "default username:password is $SSHD_USERS" >&2
fi
echo "Include /etc/ssh/sshd_config.d/*.conf" >> /etc/ssh/sshd_config
# Put our nondefault settings in extra files.
if [ ! -d /etc/ssh/sshd_config.d ]; then
  install -d /etc/ssh/sshd_config.d
fi
echo "PermitRootLogin no" >> /etc/ssh/sshd_config.d/02secure.conf
echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config.d/02secure.conf
echo "AllowTcpForwarding no" >> /etc/ssh/sshd_config.d/02secure.conf
echo "PasswordAuthentication no" >> /etc/ssh/sshd_config.d/02secure.conf

# SSHD_USERS is a space-separated list.
# Usernames can be
# - an url, pointing to the pubkey(s), e.g. https://github.com/lausser.keys
#   the username will be the last part without the file extension
# - username:password

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
      sed -ri "s/PasswordAuthentication no/PasswordAuthentication yes/g" /etc/ssh/sshd_config.d/02secure.conf
    fi
    install -o ${USERNAME} -g ${USERNAME} -m 700 -d /home/${USERNAME}/.ssh
    if [ -n "$URL" ]; then
      retries=3
      while [ $retries -gt 0 ]; do
        # Run curl and store HTTP status code in $status_code
        status_code=$(curl --write-out "%{http_code}" --silent --location --output /home/${USERNAME}/.ssh/authorized_keys "${URL}")
        if [ "$status_code" -eq 200 ]; then
          # http request succeeded, check if the file actually has content
          if [ -s /home/${USERNAME}/.ssh/authorized_keys ]; then
            echo "authorized_keys for $USERNAME downloaded successfull"
            break
          else
            echo "authorized_keys for $USERNAME has zero size"
          fi
        else
          echo "authorized_keys for $USERNAME download failed with $status_code"
        fi
          ((retries--))
          sleep 10
      done
    fi
  fi
done

# Explicitely allow the users from $SSHD_USERS
# All the other users in /etc/password cannot login via ssh
echo "AllowUsers ${ALLOWUSERS}" >> /etc/ssh/sshd_config.d/01allowusers.conf

# Create default host keys.
ssh-keygen -A

# If you want them to persist, then mount a folder on /config/ssh/keys, where they will
# be saved and reused if the container restarts.
# You can also create your own hostkeys outside the container and initially
# place them in the mounted /config/ssh/keys and the container will use them.
if [ ! -d /config/ssh/keys ]; then
  install -d /config/ssh/keys
fi

for HOST_KEY in /etc/ssh/ssh_host_*_key; do
    TYPE=$(cut -d_ -f3 <<< ${HOST_KEY##*/})
    if [ ! -f /config/ssh/keys/ssh_host_${TYPE}_key ]; then
        # You did not provide a host key of this type, so we create a new one.
        ssh-keygen -q -f /config/ssh/keys/ssh_host_${TYPE}_key -t ${TYPE} -N ''
    fi
    # Delete the one from the default -A generation.
    rm -f /etc/ssh/ssh_host_${TYPE}_key*
    # Link the persistent one.
    ln -s /config/ssh/keys/ssh_host_${TYPE}_key* /etc/ssh
done

# Privilege separation.
test -d /var/run/sshd || install -d /var/run/sshd

# Finally run the ssh daemon (logging to stderr)
exec /usr/sbin/sshd -D -e -p ${SSHD_PORT}
