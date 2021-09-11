#!/usr/bin/env bash


# Echo to stderr
function echo_err() {
  echo "$@" 1>&2;
}

# Ask the user a yes/no question and return "1" if
function ask_yn() {
  local yn;
  while true; do
    read -p "$1 " yn;
    case $yn in
      [Yy]* ) echo 1; break;;
      [Nn]* ) break;;
      * ) echo_err "Please answer yes or no.";;
    esac
  done
}

NAME=""
function get_name() {
  local n1;
  local n2;
  while [[ -z "$NAME" ]]; do
    read -p "Full Name: " n1
    read -p "Full Name (again): " n2

    if [[ "$n1" == "$n2" ]]; then
      NAME="$n1"
    else
      echo_err "$n1 and $n2 do not match!"
    fi
  done
  echo "$NAME"
}

EMAIL=""
function get_email() {
  local n1;
  local n2;
  while [[ -z "$EMAIL" ]]; do
    read -p "Email: " n1
    read -p "Email (again): " n2

    if [[ "$n1" == "$n2" ]]; then
      export EMAIL="$n1"
    fi
  done
  echo "$EMAIL"
}

read -r -d '' SSH_SCRIPT <<EOF
SSH_ENV="$HOME/.ssh/agent-environment"

function start_agent {
    echo "Initialising new SSH agent..."
    /usr/bin/ssh-agent | sed 's/^echo/#echo/' > "${SSH_ENV}"
    echo succeeded
    chmod 600 "${SSH_ENV}"
    . "${SSH_ENV}" > /dev/null
    /usr/bin/ssh-add;
}

# Source SSH settings, if applicable
if [ -f "${SSH_ENV}" ]; then
    . "${SSH_ENV}" > /dev/null
    ps -ef | grep ${SSH_AGENT_PID} | grep ssh-agent$ > /dev/null || {
        start_agent;
    }
else
    start_agent;
fi
EOF

if [[ $(ask_yn "Setup SSH? (Y/N)") ]]; then
  echo "Installing SSH Configuration...";
  echo "$SSH_SCRIPT" > "$HOME/.bash_ssh"

  _SSH_COMMAND='[[ -f "~/.bash_ssh" ]] && . "~/.bash_ssh"'
  if [[ -z $(grep "$_SSH_COMMAND" "$HOME/.bashrc") ]]; then
    echo "$_SSH_COMMAND" >> "$HOME/.bashrc";
  fi

  if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
    ssh-keygen -o -a 100 -t ed25519 -f "$HOME/.ssh/id_ed25519" -q -N "" -C "$(get_email)"
  fi
fi

if [[ $(ask_yn "Setup NVM? (Y/N)") ]]; then
  echo "Installing NVM...";
  sudo apt install -y jq
  LATEST_TAG=$(curl -s https://api.github.com/repos/nvm-sh/nvm/tags | jq -r '.[0].name');
  curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/$LATEST_TAG/install.sh" | bash
fi

if [[ $(ask_yn "Setup Rust-Up? (Y/N)") ]]; then
  echo "Installing Rust-Up...";
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh;
fi

if [[ $(ask_yn "Setup GVM (Golang Version Manager)? (Y/N)") ]]; then
  echo "Installing GVM...";
  bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
fi

if [[ $(ask_yn "Setup Git? (Y/N)") ]]; then
  echo "Installing Git...";
  sudo apt install -y git;

  NAME=$(get_name);
  EMAIL=$(get_email);

  git config --global user.name "$NAME"
  git config --global user.email "$EMAIL"
fi

if [[ $(ask_yn "Setup GPG Key? (Y/N)" ) ]]; then
  echo "Configuring GPG Key...";

  sudo apt-get install gnupg2

  GPG_KEY=$(gpg --list-secret-keys --keyid-format LONG | grep sec | awk '{ print $2 }' | sed 's/.*\///' | head -n 1);
  if [[ -z "$GPG_KEY" ]]; then
    NAME=$(get_name);
    EMAIL=$(get_email);
    # Silently generate a GPG key with a blank passphrase (or with an environment variable "GPG_PASSPHRASE")
    # that never expires.
    gpg --batch --passphrase "$GPG_PASSPHRASE" --quick-gen-key "$NAME <$EMAIL>" default default never;
    GPG_KEY=$(gpg --list-secret-keys --keyid-format LONG | grep sec | awk '{ print $2 }' | sed 's/.*\///' | head -n 1);
  fi

  read -p "Where to export the GPG Public Key? " GPG_KEY_FILE;
  gpg --armor --export "$GPG_KEY" > "$GPG_KEY_FILE";
  echo "Exported GPG public key to: $GPG_KEY_FILE";

  git config --global gpg.program gpg2
  git config --global user.signingkey "$GPG_KEY"
  git config --global commit.gpgsign true
fi
