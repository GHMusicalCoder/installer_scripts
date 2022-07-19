#!/usr/bin/env bash
LC_ALL=C

#add shellcheck call to development


################################################################################################################
############################################ SUPPORTING FUNCTIONS ##############################################
################################################################################################################
function get_github_cache() {
    CACHE_FILE="${1}"
    if [ ! -e "${CACHE_FILE}" ] || test "$(find "${CACHE_FILE}" -mmin +60)"; then
        if ! wget -q "${2}" -O "${CACHE_FILE}"; then
            messenger warn "Updating the BW-CLI Installation cache failed.  Deleting it." 
            rm "${CACHE_FILE}" 2>/dev/null
        fi
    fi

    if [ -f "${CACHE_FILE}" ] && grep "API rate limit exceeded" "${CACHE_FILE}"; then
        messenger warn "Updating ${CACHE_FILE} exceeded GitHub API limits.  Deleting it."
        rm "${CACHE_FILE}" 2>/dev/null
    fi
}

function download_file() {
    if [ ! -f "${CACHE_DIR}/${2}" ]; then
        if ! wget --quiet --continue --show-progress --progress=bar:force:noscroll "${1}" -O "${CACHE_DIR}/${2}"; then
            messenger error "Failed to download ${1}. Deleting ${CACHE_DIR}/${2}..."
            rm "${CACHE_DIR}/${2}" 2>/dev/null
        fi
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
############################################ INSTALLATION FUNCTIONS ############################################
################################################################################################################
function build_directories() {
    messenger info "Creating HOME directories..."
    cd
    mkdir -p {Development,.config/gitcreds,.icons/Sweet-Purple,.themes,Temp,Applications/{AppImages,GitApps,SingularApps},Data,Work/ObsidianNotes}
    if [ "${COMP_NAME}" == "the-doctor" ] || [ "${COMP_NAME}" == "the-tardis" ]; then
        messenger info "Creating additional personal HOME directories..."
        mkdir -p {Applications/SingularApps/yt-dlp,NASShares,Documents/{Books,Gaming,Magazines,Recipes},Videos/{CTT,Wimpy}}
    fi
}

function load_install_script() {
    messenger info "Bringing installer script and files down from GitHub..."
    cd "${HOME}/Development"
    git clone https://github.com/GHMusicalCoder/installer_scripts.git
}

function config_github() {
    messenger info "Configure github credentials..."
    cp -v "${VENTOY_FILES}/github.creds" "${HOME}/.config/gitcreds"
    cp -v "${GIT_DIR}/files/github.config" "${HOME}/.config/gitcreds"
}

function config_gitlab() {
    messenger info "Configure gitlab credentials..."
    cp -v "${VENTOY_FILES}/gitlab.creds" "${HOME}/.config/gitcreds"
    cp -v "${GIT_DIR}/files/gitlab.config" "${HOME}/.config/gitcreds"
}

function system_apps() {
    messenger info "Adding system apps via apt-get"
    ${INSTALL} build-essential dcfldd dconf-editor gddrescue gparted \
        libbz2-dev libcairo2-dev libffi-dev libgirepository1.0-dev liblzma-dev \
        libncurses5-dev libncursesw5-dev libreadline-dev libssl-dev libxmlsec1-dev libxml2-dev \
        llvm lsscsi make mlocate net-tools nfs-common nmap p7zip-rar pavucontrol \
        rar software-properties-common tk-dev ttf-mscorefonts-installer unrar vim wget xz-utils

    messenger info "Adding system apps via deb-get"
    ${DG_INSTALL} appimagelauncher bitwarden fd git-delta lsd ubuntu-make
}

function system_bw-cli() {
    messenger info "Adding Bitwarden CLI..."
    CACHE_FILE="${CACHE_DIR}/bw-cli.json"
    get_github_cache "${CACHE_FILE}" "https://api.github.com/repos/bitwarden/cli/releases/latest"

    URL=$(grep "browser_download_url.*.zip" "${CACHE_FILE}" | head -n1 | cut -d'"' -f4)
    FILE="${URL##*/}"

    download_file "${URL}" "${FILE}"

    unzip -qq "${CACHE_DIR}/${FILE}" -d "${CACHE_DIR}"

    mv "${CACHE_DIR}/bw" "${BIN_DIR}/bin"
    chmod 755 "${ZIP_DIR}/bw"
}

function system_btop() {
    messenger info "Installing btop++ ..."
    CACHE_FILE="${CACHE_DIR}/btop.json"
    get_github_cache "${CACHE_FILE}" "https://api.github.com/repos/aristocratos/btop/releases/latest"

    URL=$(grep "browser_download_url.*-x86_64-linux-musl.tbz" "${CACHE_FILE}" | head -n1 | cut -d'"' -f4)
    FILE="${URL##*/}"

    download_file "${URL}" "${FILE}"

    # make temp folder - unzip file - then run make
    WORK="${CACHE_DIR}/btop"
    mkdir -p "${WORK}"; 
    tar -xjf "${CACHE_DIR}/${FILE}" -C "${WORK}"
    cd "${WORK}"
    make install PREFIX="${BIN_DIR}"

    cd "$ACTIVE_DIR"
}


function final_cleanup() {
    messenger info "Removing undesired fonts..."
    ${SUDO} ${APT} purge -y fonts-kacst* fonts-gubbi fonts-kalapi fonts-telu* fonts-lklug* fonts-beng* \
        fonts-deva* fonts-gargi fonts-guru* fonts-nakula fonts-orya* fonts-sahadeva fonts-samyak* fonts-sarai* \
        fonts-smc* fonts-lohit* fonts-navilu* fonts-gujr* fonts-yrsa* 
    ${SUDO} ${APT} autoremove -y
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
DG_INSTALL=""
COMP_NAME="$(hostname)"
VENTOY_FILES="/media/$USER/ventoy/InstallScript/files"
HOME="/home/$USER"
GIT_DIR="${HOME}/Development/installer_scripts"
BIN_DIR="${HOME}/.local"
CACHE_DIR="${HOME}/Temp"
ACTIVE_DIR="$(pwd)"

messenger info "Installing dependencies..."
# ${SUDO} ${APT} update
# ${INSTALL} git curl lsb-core


if ! command -v deb-get 1>/dev/null; then
    messenger info "Installing deb-get for additional 3rd party app management..."
    curl -sL https://raw.githubusercontent.com/wimpysworld/deb-get/main/deb-get | sudo -E bash -s install deb-get
else
    messenger progress "deb-get is installed and ready for use..."
fi
    
DEB="deb-get"
DG_INSTALL="${DEB} install"

messenger info "Starting installation process..."
#build_directories
#config_github
#config_gitlab
#system_bw-cli
system_btop

#final_cleanup
