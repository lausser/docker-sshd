set -ex
bash
USERNAME=lausser
IMAGE=git-watch-hook
podman build -t $USERNAME/$IMAGE:latest .
