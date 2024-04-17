#!/bin/bash
set -euxo pipefail

if [ $# -ne 2 ]
then
  echo >2 "USAGE: ./install_validator.sh SSH_DESTINATION HOTKEY_PATH"
  exit 1
fi

SSH_DESTINATION="$1"
LOCAL_HOTKEY_PATH=$(realpath "$2")
LOCAL_COLDKEY_PUB_PATH=$(dirname $(dirname "$LOCAL_HOTKEY_PATH"))/coldkeypub.txt

if [ ! -f $LOCAL_HOTKEY_PATH ]; then
  echo "Given HOTKEY_PATH does not exist"
  exit 1
fi

# BSD (mac) `realpath` does not support `-s` or `--relative-to` :'(
REMOTE_HOTKEY_PATH=$(python3 -c "import os.path; print(os.path.relpath('$LOCAL_HOTKEY_PATH', '$HOME'))")
REMOTE_COLDKEY_PUB_PATH=$(python3 -c "import os.path; print(os.path.relpath('$LOCAL_COLDKEY_PUB_PATH', '$HOME'))")
REMOTE_HOTKEY_DIR=$(dirname "$REMOTE_HOTKEY_PATH")

# Copy the wallet files to the server
ssh "$SSH_DESTINATION" <<ENDSSH
set -euxo pipefail

mkdir -p $REMOTE_HOTKEY_DIR
cat > tmpvars <<ENDCAT
HOTKEY_NAME="$(basename "$REMOTE_HOTKEY_PATH")"
WALLET_NAME="$(basename $(dirname "$REMOTE_HOTKEY_DIR"))"
ENDCAT
ENDSSH
scp "$LOCAL_HOTKEY_PATH" "$SSH_DESTINATION:$REMOTE_HOTKEY_PATH"
scp "$LOCAL_COLDKEY_PUB_PATH" "$SSH_DESTINATION:$REMOTE_COLDKEY_PUB_PATH"

ssh "$SSH_DESTINATION" <<'ENDSSH'
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

# install docker
sudo apt-get update
sudo apt-get install -y ca-certificates curl docker.io docker-compose
sudo usermod -aG docker $USER
ENDSSH

# start a new ssh connection so that usermod changes are effective
ssh "$SSH_DESTINATION" <<'ENDSSH'
set -euxo pipefail
mkdir ~/compute_horde_validator
cd ~/compute_horde_validator

cat > docker-compose.yml <<'ENDDOCKERCOMPOSE'
version: '3.7'

services:

  validator-runner:
    image: backenddevelopersltd/compute-horde-validator-runner:v0-latest
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - "$HOME/.bittensor/wallets:/root/.bittensor/wallets"
      - ./.env:/root/validator/.env
    labels:
      - "com.centurylinklabs.watchtower.enable=true"

  watchtower:
    image: containrrr/watchtower:latest
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: --interval 60 --cleanup --label-enable
ENDDOCKERCOMPOSE

cat > .env <<ENDENV
SECRET_KEY=$(python3 -c 'import secrets; print(secrets.token_hex(25))')
POSTGRES_PASSWORD=$(python3 -c 'import secrets; print(secrets.token_hex(8))')
BITTENSOR_NETUID=12
BITTENSOR_NETWORK=finney
BITTENSOR_WALLET_NAME=$(. ~/tmpvars && echo "$WALLET_NAME")
BITTENSOR_WALLET_HOTKEY_NAME=$(. ~/tmpvars && echo "$HOTKEY_NAME")
HOST_WALLET_DIR=$HOME/.bittensor/wallets
FACILITATOR_URI=wss://facilitator.computehorde.io/ws/v0/
ENDENV

docker pull backenddevelopersltd/compute-horde-validator:v0-latest
docker-compose up -d

ENDSSH
