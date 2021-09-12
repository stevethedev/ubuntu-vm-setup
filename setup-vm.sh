#!/usr/bin/env bash

###############################################################################
#                              Utility Functions                              #
###############################################################################

# Computes a text value and deposits the result into the provided variable.
#
# Parameters:
#  1. Value to check against the string '1'
#  2. Value to assign if $1 == '1'
#  3. Value to assign if $1 != '1'
#
# Echos
#  "$2" if $1 == '1' else "$3"
iftext() {
  local CHECK_VAR="$1"
  local IF_TRUE="$2"
  local IF_FALSE="$3"

  if [[ "$CHECK_VAR" == '1' ]]; then
    echo "$IF_TRUE"
  else
    echo "$IF_FALSE"
  fi
}

# Computes a checkbox value and deposits the result into the provided variable.
#
# Parameters:
#  1. Value to check against the string '1'
#
# Echos:
#  '[X]' if $1 == '1', else '[ ]'
checkmark() {
  local CHECK_VAR="$1"

  iftext "$CHECK_VAR" '[X]' '[ ]'
}

# Toggles the provided variable, so that if it is truthy then it becomes falsy, and vice-versa
#
# Parameters:
#  1. Variable name to toggle between 0 and 1.
toggle() {
  local TOGGLE_VAR="$1"
  printf -v "$TOGGLE_VAR" '%s' "$(((1 + "$TOGGLE_VAR") % 2))"
}

# Presents an alert message to the user.
#
# Parameters:
#  1. The dialog's title.
#  2. The dialog's message.
message() {
  local DIALOG_TITLE="$1"
  local DIALOG_MESSAGE="$2"
  whiptail --title "$DIALOG_TITLE" --msgbox "$DIALOG_MESSAGE" 8 78
}

# Receives text input with the provided questions, and deposits the response into the provided variable.
#
# Parameters
#  1. The variable name to deposit the result into.
#  2. The dialog's title.
#  3. The dialog's query text.
text_input() {
  local VAR_NAME="$1"
  local DIALOG_MESSAGE="$2"
  local QUERY_TEXT="$3"

  local INPUT
  local STATUS

  INPUT=$(
    whiptail \
      --title "$DIALOG_MESSAGE" \
      --ok-button "[ENTER] Ok" \
      --cancel-button "[ESC] Cancel" \
      --inputbox "$QUERY_TEXT" 8 78 "${!VAR_NAME}" \
      3>&1 1>&2 2>&3
  )

  STATUS=$?
  if [[ $STATUS -eq 0 ]]; then
    printf -v "$VAR_NAME" '%s' "$INPUT"
  fi

  return $STATUS
}

# Presents a confirmation dialog to the user for a given query
#
# Parameters:
#  1. The variable to deposit the results into.
#  2. The dialog's title.
#  3. The dialog's query-text.
confirm_input() {
  local VAR_NAME="$1"
  local DIALOG_MESSAGE="$2"
  local QUERY_TEXT="$3"

  local STATUS

  whiptail \
    --title "$DIALOG_MESSAGE" \
    --yesno "$QUERY_TEXT" 8 78 \
    3>&1 1>&2 2>&3

  STATUS=$?

  printf -v "$VAR_NAME" '%s' "$STATUS"
  toggle "$VAR_NAME"

  return $STATUS
}

# Enters a loop where the user either cancels or provides the same passphrase
# twice, and sets the provided variable to the confirmed value.
#
# Parameters:
#  1. The variable to save the password into
#  2. The message to put on the dialog box
password_input() {
  local VAR_NAME="$1"
  local DIALOG_MESSAGE="$2"

  local INPUT1
  local INPUT2
  local STATUS

  while true; do
    INPUT1=$(
      whiptail \
        --title "Enter passphrase" \
        --ok-button "[ENTER] Continue" \
        --cancel-button "[ESC] Cancel" \
        --passwordbox "$DIALOG_MESSAGE" 8 78 "" \
        3>&1 1>&2 2>&3
    )

    STATUS=$?
    if [[ $STATUS -ne 0 ]]; then
      break
    fi

    INPUT2=$(
      whiptail \
        --title "Confirm passphrase" \
        --ok-button "[ENTER] Save" \
        --cancel-button "[ESC] Cancel" \
        --passwordbox "$DIALOG_MESSAGE" 8 78 "" \
        3>&1 1>&2 2>&3
    )

    STATUS=$?
    if [[ $STATUS -ne 0 ]]; then
      break
    fi

    if [[ "$INPUT1" == "$INPUT2" ]]; then
      printf -v "$VAR_NAME" '%s' "$INPUT1"
      break
    fi

    message 'The passphrases did not match' 'Your passphrase will not be saved'
  done
}

# Load the current GPG keys and identify the one for the provided user information.
#
# Parameters
#  1. Target variable to load the key into
#  2. User info to match
find_gpg_key() {
  local VAR_NAME="$1"
  local USER_STRING="$2"

  local FOUND_KEY

  if [[ "$(which gpg)" != '' ]]; then
    FOUND_KEY="$(gpg --list-secret-keys --keyid-format LONG "$USER_STRING" 2>/dev/null | grep -E '^sec' | awk '{print $2}' | cut -d'/' -f 2)"
  fi

  printf -v "$VAR_NAME" '%s' "$FOUND_KEY"
}

# Load the current GPG keys and identify the email associated with the current user
#
# Parameters
#  1. Target variable to load the email into
#  2. User info to match
find_gpg_email() {
  local VAR_NAME="$1"
  local USER_STRING="$2"

  local FOUND_KEY

  if [[ "$(which gpg)" != '' ]]; then
    FOUND_KEY="$(gpg --list-secret-keys --keyid-format LONG "$USER_STRING" 2>/dev/null | grep -E '^uid' | sed -e 's/.*<//' -e 's/>.*//')"
  fi

  printf -v "$VAR_NAME" '%s' "$FOUND_KEY"
}

# Echoes the menu-text for the Git option
git_menu_text() {
  if [[ "$_USE_GIT" == '1' ]]; then
    if [[ "$_USE_GPG" == '1' ]] && [[ "$_GPG_AUTO_SIGN_COMMITS" == '1' ]]; then
      echo 'Use Git + GPG Autosign'
    else
      echo 'Use Git'
    fi
  else
    echo 'Skip Git'
  fi
}

# Echoes the menu-text for the Languages option
lang_menu_text() {
  local L=()

  if [[ "$_USE_GVM" == '1' ]]; then
    L+=("Go ($_GVM_GOLANG_VERSION)")
  fi

  if [[ "$_USE_RUST" == '1' ]]; then
    L+=("Rust (latest)")
  fi

  if [[ "$_USE_NVM" == '1' ]]; then
    L+=("Node ($_NVM_NODE_VERSION)")
  fi

  if [[ ${#L[@]} -gt 0 ]]; then
    L="$(printf ", %s" "${L[@]}")"
    echo "Languages: ${L:2}"
  else
    echo 'Languages: <none>'
  fi
}

###############################################################################
#                             Interface Functions                             #
###############################################################################

# Presents the Main Menu loop.
main_menu() {
  local OPTIONS
  local CHOICE
  local STATUS

  while true; do
    OPTIONS=()
    OPTIONS+=('u)' "User: $_NAME <$_EMAIL>")
    OPTIONS+=('s)' "$(iftext "$_USE_SSH" "SSH: $_SSH_TOKEN" 'Skip SSH')")
    OPTIONS+=('g)' "$(git_menu_text)")
    OPTIONS+=('p)' "$(iftext "$_USE_GPG" 'Use GPG' 'Skip GPG')")
    OPTIONS+=('l)' "$(lang_menu_text)")
    OPTIONS+=('x)' 'Continue to Installation')

    CHOICE=$(
      whiptail \
        --title 'Setup Ubuntu' \
        --ok-button "[ENTER] Select" \
        --cancel-button "[ESC] Cancel" \
        --menu 'Make your choice' 16 100 9 "${OPTIONS[@]}" \
        3>&2 2>&1 1>&3
    )

    STATUS=$?
    if [[ $STATUS -ne 0 ]]; then
      _DO_INSTALL=0
      break
    fi

    case "$CHOICE" in
    'u)')
      user_menu
      ;;
    's)')
      ssh_menu
      ;;
    'g)')
      git_menu
      ;;
    'p)')
      gpg_menu
      ;;
    'l)')
      lang_menu
      ;;
    'x)')
      break
      ;;
    esac
  done
}

# Allow the user to set their personal information
user_menu() {
  local OPTIONS
  local CHOICE
  local STATUS

  while true; do
    OPTIONS=()
    OPTIONS+=('n)' "Name: $_NAME")
    OPTIONS+=('e)' "Email: $_EMAIL")

    CHOICE=$(
      whiptail \
        --title 'Configure User Information' \
        --ok-button "[ENTER] Select" \
        --cancel-button "[ESC] Back" \
        --menu 'Make your choice' 16 100 9 "${OPTIONS[@]}" \
        3>&2 2>&1 1>&3
    )

    STATUS=$?
    if [[ $STATUS -ne 0 ]]; then
      break
    fi

    case "$CHOICE" in
    'n)')
      text_input _NAME 'Configure User' 'What is your real name?'
      ;;
    'e)')
      text_input _EMAIL 'Configure User' 'What is your email?'
      ;;
    esac
  done

  find_gpg_key _GPG_KEY "$_NAME <$_EMAIL>"
}

# Presents the SSH Menu loop
ssh_menu() {
  local OPTIONS
  local CHOICE
  local STATUS

  while true; do
    OPTIONS=()
    OPTIONS+=('e)' "$(checkmark "$_USE_SSH") Enable SSH installation & configuration")

    if [[ "$_USE_SSH" == '1' ]]; then
      OPTIONS+=('t)' "SSH Token: $_SSH_TOKEN")

      if [[ -f "$_SSH_TOKEN" ]]; then
        OPTIONS+=('o)' "$(checkmark "$_SSH_TOKEN_OVERWRITE") Overwrite existing SSH token")
      fi
    fi

    CHOICE=$(
      whiptail \
        --title 'Configure SSH' \
        --ok-button "[ENTER] Select" \
        --cancel-button "[ESC] Back" \
        --menu 'Make your choice' 16 100 9 "${OPTIONS[@]}" \
        3>&2 2>&1 1>&3
    )

    STATUS=$?
    if [[ $STATUS -ne 0 ]]; then
      break
    fi

    case "$CHOICE" in
    'e)')
      toggle _USE_SSH
      ;;
    't)')
      text_input _SSH_TOKEN 'Configure SSH' 'What is the SSH token file-path?'
      ;;
    'o)')
      toggle _SSH_TOKEN_OVERWRITE
      ;;
    esac
  done
}

# Presents the Git-configuration menu loop.
git_menu() {
  local OPTIONS
  local CHOICE
  local STATUS

  while true; do
    OPTIONS=()
    OPTIONS+=('e)' "$(checkmark "$_USE_GIT") Install and configure Git")

    if [[ "$_USE_GIT" == '1' ]]; then
      if [[ "$_USE_GPG" == '1' ]]; then
        OPTIONS+=('s)' "$(checkmark "$_GPG_AUTO_SIGN_COMMITS") Use GPG to auto-sign Git Commits")
      fi
    fi

    CHOICE=$(
      whiptail \
        --title 'Configure Git' \
        --ok-button "[ENTER] Select" \
        --cancel-button "[ESC] Back" \
        --menu 'Make your choice' 16 100 9 "${OPTIONS[@]}" \
        3>&2 2>&1 1>&3
    )

    STATUS=$?
    if [[ $STATUS -ne 0 ]]; then
      break
    fi

    case "$CHOICE" in
    'e)')
      toggle _USE_GIT
      ;;
    's)')
      toggle _GPG_AUTO_SIGN_COMMITS
      ;;
    esac
  done
}

# Presents the GPG menu loop
gpg_menu() {
  local OPTIONS
  local CHOICE
  local STATUS

  while true; do
    OPTIONS=()
    OPTIONS+=('e)' "$(checkmark "$_USE_GPG") Install and configure GPG")

    if [[ "$_USE_GPG" == '1' ]]; then
      OPTIONS+=('o)' "Output Pubkey: $_GPG_KEY_FILE")

      if [[ "$_USE_GIT" == '1' ]]; then
        OPTIONS+=('s)' "$(checkmark "$_GPG_AUTO_SIGN_COMMITS") Auto-sign Git commits")
      fi

      if [[ "$_GPG_KEY" == '' ]]; then
        OPTIONS+=('p)' "Password (${#_GPG_PASSPHRASE} characters)")
      fi
    fi

    CHOICE=$(
      whiptail \
        --title 'Configure GPG' \
        --ok-button "[ENTER] Select" \
        --cancel-button "[ESC] Back" \
        --menu 'Make your choice' 16 100 9 "${OPTIONS[@]}" \
        3>&2 2>&1 1>&3
    )

    STATUS=$?
    if [[ $STATUS -ne 0 ]]; then
      break
    fi

    case "$CHOICE" in
    'e)')
      toggle _USE_GPG
      ;;
    'o)')
      text_input _GPG_KEY_FILE 'GPG Pubkey' 'Where do you ant to save the exported GPG token public key?'
      ;;
    's)')
      toggle _GPG_AUTO_SIGN_COMMITS
      ;;
    'p)')
      password_input _GPG_PASSPHRASE 'Set the GPG Passphrase (or leave blank for no passphrase)'
      ;;
    esac
  done
}

lang_menu() {
  local OPTIONS
  local CHOICE
  local STATUS

  while true; do
    OPTIONS=()
    OPTIONS+=('n)' "$(checkmark "$_USE_NVM") Node Version Manager (NVM)")
    OPTIONS+=('g)' "$(checkmark "$_USE_GVM") Golang Version Manager (GVM)")
    OPTIONS+=('r)' "$(checkmark "$_USE_RUST") Rust (rustup)")

    CHOICE=$(
      whiptail \
        --title 'Configure Installed Languages' \
        --ok-button "[ENTER] Select" \
        --cancel-button "[ESC] Back" \
        --menu 'Make your choice' 16 100 9 "${OPTIONS[@]}" \
        3>&2 2>&1 1>&3
    )

    STATUS=$?
    if [[ $STATUS -ne 0 ]]; then
      break
    fi

    case "$CHOICE" in
    'n)')
      toggle _USE_NVM
      ;;
    'g)')
      toggle _USE_GVM
      ;;
    'r)')
      toggle _USE_RUST
      ;;
    esac
  done
}

###############################################################################
#                         Application Global Variables                        #
###############################################################################

# Indicates that the installation process should continue.
_DO_INSTALL=1

# Indicates whether to install SSH support.
_USE_SSH='1'

# Indicates the name of the SSH token.
_SSH_TOKEN="$HOME/.ssh/id_ed25519"

# Indicates that the existing token should be used
_SSH_TOKEN_OVERWRITE='0'

# Indicates the user's real name. Defaults to the name given to Ubuntu during
# the initial setup.
_NAME="$(getent passwd "$(whoami)" | cut -d ':' -f 5 | cut -d ',' -f 1)"

# Indicates the user's email, for Git and GPG.
_EMAIL=''
find_gpg_email _EMAIL "$_NAME"

# Indicates whether to install and configure Git
_USE_GIT='1'

# Indicates whether to install and configure GPG
_USE_GPG='1'

# Indicates the GPG passphrase to use with the generated GPG token
_GPG_PASSPHRASE=''

# Indicates the GPG key ID to use; or else leave blank to generate a key
_GPG_KEY=''
find_gpg_key _GPG_KEY "$_NAME"

_GPG_KEY_ALGO='default'
_GPG_KEY_USAGE='default'
_GPG_KEY_EXPIRE='never'

# Indicates where the exported GPG token's public key should be placed
_GPG_KEY_FILE="${PWD}/gpg-token.pub"

# Indicates that git commits should be auto-signed with the GPG key
_GPG_AUTO_SIGN_COMMITS='1'

# Indicates whether to install the Golang Version Manager
_USE_GVM='0'
_GVM_GOLANG_VERSION='go1'

# Indicates whether to install the Node Version Manager
_USE_NVM='0'
_NVM_NODE_VERSION='stable'

# Indicates whether to install Rustup
_USE_RUST='0'

###############################################################################
#                        Application Installation Logic                       #
###############################################################################

read -r -d '' SSH_SCRIPT <<'EOF'
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

install_ssh() {
  local SSH_COMMAND

  if [[ "$_USE_SSH" != '1' ]]; then
    echo "Skipping SSH Configuration..."
    return 1
  fi

  echo "Installing SSH Configuration..."
  echo "$SSH_SCRIPT" >"$HOME/.bash_ssh"

  SSH_COMMAND='[[ -f "~/.bash_ssh" ]] && . "~/.bash_ssh"'
  if ! grep -q "$SSH_COMMAND" "$HOME/.bashrc"; then
    echo "$SSH_COMMAND" >> "$HOME/.bashrc"
  fi

  if [[ -f "$_SSH_TOKEN" ]]; then
    if [[ "$_SSH_TOKEN_OVERWRITE" != '1' ]]; then
      echo "Use existing token: $_SSH_TOKEN"
      return 0
    fi
    echo "Replacing existing SSH token: $_SSH_TOKEN"
    rm -f "$_SSH_TOKEN"
    rm -f "${_SSH_TOKEN}.pub"
  fi

  ssh-keygen -o -a 100 -t ed25519 -f "$_SSH_TOKEN" -q -N "" -C "$_NAME <$_EMAIL>"
}

install_nvm() {
  local LATEST_TAG

  if [[ "$_USE_NVM" != '1' ]]; then
    echo "Skipping NVM installation..."
    return 1
  fi

  echo "Installing NVM..."
  sudo apt install -y jq
  LATEST_TAG=$(wget -q -O - 'https://api.github.com/repos/nvm-sh/nvm/tags' | jq -r '.[0].name')
  wget -q -O - "https://raw.githubusercontent.com/nvm-sh/nvm/$LATEST_TAG/install.sh" | bash
  bash -i -c "nvm install '$_NVM_NODE_VERSION'"
}

install_rust() {
  if [[ "$_USE_RUST" != '1' ]]; then
    echo "Skipping Rust-Up installation..."
    return 1
  fi

  echo "Installing Rust-Up..."
  wget --https-only --secure-protocol='TLSv1_2' -q -O - 'https://sh.rustup.rs' | sh
}

install_gvm() {
  local GOLANG_VERSION

  if [[ "$_USE_GVM" != '1' ]]; then
    echo "Skipping GVM installation..."
    return 1
  fi

  echo "Installing GVM..."
  sudo apt install -y binutils make gcc curl bison
  wget -q -O - 'https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer' | bash
  GOLANG_VERSION="$(bash -i -c 'gvm listall' | awk '{print $1}' | grep -E '^go' | grep -v 'beta' | grep "$_GVM_GOLANG_VERSION" | tail -n1)"
  bash -i -c "gvm install '$GOLANG_VERSION' -B"
}

install_git() {
  if [[ "$_USE_GIT" != '1' ]]; then
    echo "Skipping Git installation..."
    return 1
  fi
  echo "Installing Git..."

  sudo apt install -y git
  git config --global user.name "$_NAME"
  git config --global user.email "$_EMAIL"
}

install_gpg() {
  if [[ "$_USE_GPG" != '1' ]]; then
    echo "Skipping GPG installation..."
    return 1
  fi
  echo "Installing GPG Key..."

  sudo apt-get install -y gnupg2

  if [[ -z "$_GPG_KEY" ]]; then
    # Silently generate a GPG key with a blank passphrase (or with an environment variable "GPG_PASSPHRASE")
    # that never expires.
    gpg --batch --passphrase "$_GPG_PASSPHRASE" --quick-gen-key "$_NAME <$_EMAIL>" "$_GPG_KEY_ALGO" "$_GPG_KEY_USAGE" "$_GPG_KEY_EXPIRE"
    find_gpg_key _GPG_KEY "$_NAME <$_EMAIL>"
  fi

  gpg --armor --export "$_GPG_KEY" >"$_GPG_KEY_FILE"
  echo "Exported GPG public key to: $_GPG_KEY_FILE"

  if [[ "$(which git)" != "" ]]; then
    git config --global gpg.program gpg2
    git config --global user.signingkey "$_GPG_KEY"

    if [[ "$_GPG_AUTO_SIGN_COMMITS" == '1' ]]; then
      git config --global commit.gpgsign true
    fi
  fi
}

###############################################################################
#                           Application Entry Point                           #
###############################################################################

main() {
  main_menu

  if [[ $_DO_INSTALL -ne 1 ]]; then
    echo 'Cancelled installation'
    exit 1
  fi

  install_ssh
  install_git
  install_gpg
  install_nvm
  install_gvm
  install_rust

  echo "Installation complete; a reboot may be required"
}

main
