#!/usr/bin/env bash
LC_ALL=C

################################################################################################################
############################################ SUPPORTING FUNCTIONS ##############################################
################################################################################################################
function config_gitlab() {
    messenger info "Configure gitlab credentials..."
    cp -v "${VENTOY_FILES}gitlab.creds" "${HOME}.config/gitcreds"
    cp -v "${GIT_DIR}files/gitlab.config" "${HOME}.config/gitcreds"
}

function config_github() {
    messenger info "Configure github credentials..."
    cp -v "${VENTOY_FILES}github.creds" "${HOME}.config/gitcreds"
    cp -v "${GIT_DIR}files/github.config" "${HOME}.config/gitcreds"
}

function load_install_script() {
    messenger info "Bringing installer script and files down from GitHub..."
    cd "${HOME}Development"
    git clone https://github.com/GHMusicalCoder/installer_scripts.git
}

function build_directories() {
    messenger info "Creating HOME directories..."
    cd
    mkdir -p {Development,.config/gitcreds,.icons/Sweet-Purple,.themes,Temp,Applications/{AppImages,GitApps,SingularApps},Data,Work/ObsidianNotes}
    if [ "${COMP_NAME}" == "the-doctor" ] || [ "${COMP_NAME}" == "the-tardis" ]; then
        messenger info "Creating additional personal HOME directories..."
        mkdir -p {Applications/SingularApps/yt-dlp,NASShares,Documents/{Books,Gaming,Magazines,Recipes},Videos/{CTT,Wimpy}}
    fi
}

function messenger() {
    if [ -z "${1}" ] || [ -z "${2}" ]; then
        return
    fi

    local RED="\e[31m"
    local GREEN="\e[32m"
    local YELLOW="\e[33m"
    local BLUE="\e[34m"
    local MAGENTA="\e[35m"
    local CYAN="\e[36m"
    local RESET="\e[0m"
    local MTYPE="${1}"
    local MSG="${2}"

    case ${MTYPE} in
        info) echo -e " [${BLUE}+${RESET}] ${CYAN}${MSG}${RESET}";;
        progress) echo -en " [${GREEN}+${RESET}] ${CYAN}${MSG}${RESET}";;
        recommend) echo -e " [${MAGENTA}!${RESET}] ${MAGENTA}${MSG}${RESET}";;
        warn) echo -e " [${YELLOW}*${RESET}] ${YELLOW}WARNING! ${MSG}${RESET}";;
        error) echo -e " [${RED}!${RESET}] ${RED}ERROR! ${MSG}${RESET}";;
        fatal) echo -e " [${RED}!${RESET}] ${RED}ERROR! ${MSG}${RESET}"
                exit 1;;
        *) echo -e " [?] UNKNOWN: ${MSG}";;
    esac
}

################################################################################################################
############################################ MAIN PROGRAM ######################################################
################################################################################################################
messenger info "Setting up configuration variables..."
SUDO="$(which sudo)"
APT="$(which apt)"
DEB=""
RM="$(which rm)"
INSTALL="${SUDO} ${APT} install -y"
COMP_NAME="$(hostname)"
VENTOY_FILES="/media/$USER/ventoy/InstallScript/files/"
HOME="/home/$USER/"
GIT_DIR="${HOME}/Development/installer-scripts/"

messenger info "Installing dependencies..."
${SUDO} ${APT} update
${INSTALL} git curl lsb-core


if ! command -v deb-get 1>/dev/null; then
    messenger info "Installing deb-get for additional 3rd party app management..."
    curl -sL https://raw.githubusercontent.com/wimpysworld/deb-get/main/deb-get | sudo -E bash -s install deb-get
else
    messenger progress "deb-get is installed and ready for use..."
fi
    
DEB="deb-get"

messenger info "Starting installation process..."
#build_directories
config_github
config_gitlab

