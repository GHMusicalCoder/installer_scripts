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
        mkdir -p {Applications/SingularApps/yt-dlp,NASShares,Pictures/{"Desktop Backgrounds",Masonic}}
        mkdir -p {/mnt/crypt,/mnt/vault}
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
    messenger info "Adding system apps..."
    ${INSTALL} build-essential dcfldd dconf-editor gddrescue gparted \
        libbz2-dev libcairo2-dev libffi-dev libgirepository1.0-dev liblzma-dev \
        libncurses5-dev libncursesw5-dev libreadline-dev libssl-dev libxmlsec1-dev libxml2-dev \
        llvm lsscsi make mlocate net-tools nfs-common nmap p7zip-rar pavucontrol \
        rar software-properties-common tk-dev ttf-mscorefonts-installer unrar vim wget xz-utils

    ${DG_INSTALL} appimagelauncher bitwarden bottom duf fd git-delta lsd ubuntu-make

    ${SUDO} flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
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

function mount_nfs_folders() {
    if [ "${COMP_NAME}" == "the-doctor" ] || [ "${COMP_NAME}" == "the-tardis" ]; then
        messenger info "Mounting NFS Volumes from NAS Box..."
        mount -t nfs 192.168.88.224:/mnt/IOUN/CLRYPT /mnt/crypt
        mount -t nfs 192.168.88.224:/mnt/IOUN/CLRYPT /mnt/crypt
        sudo echo "192.168.88.224:/mnt/IOUN/CRYPT /mnt/crypt nfs defaults 0 0" >> /etc/fstab
        sudo echo "192.168.88.224:/mnt/OGHMA/VAULT /mnt/vault nfs defaults 0 0" >> /etc/fstab

        messenger info "Creating symbolic links..."
        ln -s "/mnt/crypt" "${HOME}/NASShares/Crypt"
        ln -s "/mnt/vault" "${HOME}/NASShares/Vault"
        ln -s "/mnt/vault/Media/Videos/CTT/" "${HOME}/Videos/CTT"
        ln -s "/mnt/vault/Media/Videos/Wimpy/" "${HOME}/Videos/Wimpy"
        ln -s "/mnt/vault/Archives/eBooks/" "${HOME}/Documents/Books"
        ln -s "/mnt/vault/Archives/Gaming/" "${HOME}/Documents/Gaming"
        ln -s "/mnt/vault/Archives/Magazines/" "${HOME}/Documents/Magazines"
        ln -s "/mnt/vault/Archives/Recipes/" "${HOME}/Documents/Recipes"
    fi
}

function system_virt_machines() {
    messenger info "Installing virtual machine apps..."
    ${SUDO} ${APT} install -y qemu qemu-kvm qemu-system qemu-utils libvirt-clients libvert-daemon-system \
        virtinst virt-manager
    ${SUDO} usermod -a -G libvirt "$USER"
    ${DG_INSTALL} quickemu quickgui
}

function laptop_install() {
    if [ "${COMP_NAME}" == "co-dev-ckiraly" ] || [ "${COMP_NAME}" == "the-tardis" ]; then
        ${SUDO} ${APT} install -y laptop-mode-tools
    fi
}

function copy_files() {
    if [ "${COMP_NAME}" == "the-doctor" ] || [ "${COMP_NAME}" == "the-tardis" ]; then
        cp "/mnt/vault/Media/Images/Desktop Backgrounds/*.*" "${HOME}/Pictures/Desktop Backrounds"
        cp "/mnt/vault/Media/Images/Masonic/*.*" "${HOME}/Pictures/Masonic"
    fi
}

function install_sweet_dark_theme() {
    messenger info "Installing Sweet Dark Theme by EliverLara"
    CACHE_FILE="${CACHE_DIR}/sweet.json"
    get_github_cache "${CACHE_FILE}" "https://api.github.com/repos/EliverLara/Sweet/releases/latest"

    URL=$(grep "browser_download_url.*Dark.zip" "${CACHE_FILE}" | head -n1 | cut -d'"' -f4)
    FILE="${URL##*/}"

    download_file "${URL}" "${FILE}"

    #verify .themes exist
    mkdir -p "${HOME}/.themes"
    unzip -qq "${CACHE_DIR}/${FILE}" -d "${HOME}/.themes"

    gsettings set org.gnome.desktop.interface gtk-theme "Sweet-Dark"
    gsettings set org.gnome.desktop.wm.preferences theme "Sweet-Dark"
}

function install_candy_icons() {
    messenger info "Installing Candy Icons by EliverLara"
    # verify .icons directory exists
    mkdir -p "${HOME}/.icons"

    URL="https://github.com/EliverLara/candy-icons/archive/refs/heads/master.zip"
    FILE="candy-icons.zip"

    download_file "${URL}" "${FILE}"
    unzip -qq "${CACHE_DIR}/${FILE}" -d "${HOME}/.icons"

    # folder name is candy-icons-master - so renaming to candy-icons
    mv "${HOME}/.icons/candy-icons-master" "${HOME}/.icons/candy-icons"

    gsettings set org.gnome.desktop.interface icon-theme candy-icons
}

function install_sweet_folders() {
    # steps 1 - clone sweet folders git repo
    mkdir -p "${HOME}/.icons/Sweet-Purple"

    cd "${CACHE_DIR}"
    git clone "https://github.com/EliverLara/Sweet-folders.git"
    cp "${CACHE_DIR}/sweet_folders/Sweet-Purple" "${HOME}/.icons/Sweet-Purple/"
    sed -i 's/^Inherits=.*/Inherits=candy-icons,breeze-dark,gnome,ubuntu-mono-dark,Mint-X,elementary,gnome,hicolor' \
        "${HOME}/.icons/Sweet-Purple/index.theme"

    cd "${ACTIVE_DIR}"
}

function install_accessories() {
    messenger info "Installing accessory applications..."
    ${DG_INSTALL} openaudible
}

function install_vs_code() {
    messenger info "Installing Visual Studio code and extensions..."
    ${DG_INSTALL} code

    # install default extensions
    code --install-extension tomaciazek.ansible
    code --install-extension rogalmic.bash-debug
    code --install-extension mads-hartmann.bash-ide-vscode
    code --install-extension yzhang.markdown-all-in-one
    code --install-extension shd101wyy.markdown-preview-enhanced
    code --install-extension vangware.dark-plus-material
    code --install-extension ms-python.python
    code --install-extension ms-python.vscode-pylance
    code --install-extension alexcvzz.vscode-sqlite
}

function install_development() {
    ${INSTALL} python3-ebooklib python3-enchant python3-gst-1.0 python3-gtkspellcheck python3-selenium python3-sqlalchemy \
        python3-sqlalchemy-ext python3-toml python3-pip python3-venv sqlite3 libsqlite3-dev

    ${DG_INSTALL} docker-ce docker-desktop gitkraken rpi-imager
    ${FLATPAK} com.jetbrains.PyCharm-Professional
}

function install_git_repos() {
    cd ${HOME}/Development
    ${CLONE} "https://gitlab.com/MusicalCoder/ansible_pull.git"
    ${CLONE} "https://gitlab.com/MusicalCoder/my-notes.git"
    ${CLONE} "https://gitlab.com/MusicalCoder/lyric-web-app.git"
    ${CLONE} "https://gitlab.com/MusicalCoder/music-karaoke-tracker.git"
    ${CLONE} "https://gitlab.com/MusicalCoder/codingsites.git"
    ${CLONE} "https://gitlab.com/MusicalCoder/personal-wikis.git"
    ${CLONE} "https://gitlab.com/MusicalCoder/tablemanager.git"
    ${CLONE} "https://gitlab.com/MusicalCoder/wordplay.git"
    ${CLONE} "https://gitlab.com/MusicalCoder/wordle-solver.git"
    ${CLONE} "https://github.com/GHMusicalCoder/rpg-cards.git"
    ${CLONE} "https://github.com/GHMusicalCoder/deb-get.git"

    cd ${ACTIVE_DIR}
}

function install_games() {
    messenger info "Installing game applications..."
    # configure system for i386
    ${SUDO} dpkg --add-architecture i386
    # download and add repo key for wine
    ${SUDO} wget -nc -0 /usr/share/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
    ${SUDO} wget -nc -P /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/${UBUNTU_NICK}/winehq-${UBUNTU_NICK}.sources
    ${SUDO} ${APT} update
    ${INSTALL} --install-recommends winehq-stable

    ${DG_INSTALL} com.github.tkashkin.gamehub lutris minigalaxy retroarch

    ${FLATPAK} com.dosbox_x.DOSBox-X

    ${INSTALL} steam frozen-bubble playonlinux wesnoth wesnoth-music
}

function install_graphics() {
    messenger info "Installing graphics applications..."
    ${INSTALL} gimp gimp-data-extras gimp-gap gimp-plugin-registry gpick pinta inkscape
}

function install_internet() {
    messenger info "Installing internet applications..."
    ${SUDO} snap purge firefox
    ${DG_INSTALL} brave-browser firefox-esr google-chrome-stable opera-stable microsoft-edge-stable element-desktop discord
    ${FLATPAK} info.mumble.Mumble
}

function install_multimedia() {
    messenger info "Installing multimedia apps..."
    ${INSTALL} ubuntu-restricted-extras ubuntu-restricted-addons libavcodec-extra \
        gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly \
        gstreamer1.0-libav handbrake handbrake-cli kodi vlc celluloid

    ${DG_INSTALL} spotify-client 
    
    ${FLATPAK} com.makemkv.MakeMKV
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
UBUNTU_NICK="jammy"
FLATPAK="${SUDO} flatpak install -y flathub"


messenger info "Installing dependencies..."
# ${SUDO} ${APT} update
# ${INSTALL} git curl lsb-core
GIT="$(which git)"
CLONE="${GIT} clone"

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
#system_btop
#system_virt_machines
#laptop_install
#install_sweet_dark_theme
#install_candy_icons
#install_sweet_folders
#install_vs_code
#install_development
#install_git_repos
#install_games
#install_graphics
#install_internet

#final_cleanup
