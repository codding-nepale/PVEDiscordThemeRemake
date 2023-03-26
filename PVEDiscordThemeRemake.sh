#!/bin/bash
# https://github.com/codding-nepale/PVEDiscordThemeRemake

umask 022

#region Consts
RED='\033[0;31m'
BRED='\033[0;31m\033[1m'
GRN='\033[92m'
WARN='\033[93m'
BOLD='\033[1m'
REG='\033[0m'
CHECKMARK='\033[0;32m\xE2\x9C\x94\033[0m'

TEMPLATE_FILE="/usr/share/pve-manager/index.html.tpl"
SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/"
SCRIPTPATH="${SCRIPTDIR}$(basename "${BASH_SOURCE[0]}")"

OFFLINEDIR="${SCRIPTDIR}offline"

REPO=${REPO:-"codding-nepale/PVEDiscordThemeRemake"}
DEFAULT_TAG="master"
TAG=${TAG:-$DEFAULT_TAG}
BASE_URL="https://raw.githubusercontent.com/$REPO/$TAG"

OFFLINE=false
#endregion Consts

#region Prerun checks
if [[ $EUID -ne 0 ]]; then
    echo -e >&2 "${BRED}Root privileges are required to perform this operation${REG}";
    exit 1
fi

hash sed 2>/dev/null || { 
    echo -e >&2 "${BRED}sed is required but missing from your system${REG}";
    exit 1;
}

hash pveversion 2>/dev/null || { 
    echo -e >&2 "${BRED}PVE installation required but missing from your system${REG}";
    exit 1;
}

if test -d "$OFFLINEDIR"; then
    echo "Offline directory detected, entering offline mode."
    OFFLINE=true
else
    hash curl 2>/dev/null || { 
        echo -e >&2 "${BRED}cURL is required but missing from your system${REG}";
        exit 1;
    }
    hash wget 2>/dev/null || { 
        echo -e >&2 "${BRED}WGET is required but missing from your system${REG}";
        exit 1;
    }
fi

if [ "$OFFLINE" = false ]; then
    curl -sSf -f https://raw.githubusercontent.com/ &> /dev/null || {
        echo -e >&2 "${BRED}Could not establish a connection to GitHub (https://raw.githubusercontent.com)${REG}";
        exit 1;
    }

    if [ $TAG != $DEFAULT_TAG ]; then
        if !([[ $TAG =~ [0-9] ]] && [ ${#TAG} -ge 7 ] && (! [[ $TAG =~ ['!@#$%^&*()_+.'] ]]) ); then 
            echo -e "${WARN}It appears like you are using a non-default tag. For security purposes, please use the SHA-1 hash of said tag instead${REG}"
        fi
    fi
fi
#endregion Prerun checks

PVEVersion=$(pveversion --verbose | grep pve-manager | cut -c 14- | cut -c -6) # Below pveversion pre-run check
PVEVersionMajor=$(echo $PVEVersion | cut -d'-' -f1)

#region Helper functions
function checkSupported {   
    if [ "$OFFLINE" = false ]; then
        local SUPPORTED=$(curl -f -s "$BASE_URL/meta/supported")
    else
        local SUPPORTED=$(cat "$OFFLINEDIR/meta/supported")
    fi

    if [ -z "$SUPPORTED" ]; then 
        if [ "$OFFLINE" = false ]; then
            echo -e "${WARN}Could not reach supported version file ($BASE_URL/meta/supported). Skipping support check.${REG}"
        else
            echo -e "${WARN}Could not find supported version file ($OFFLINEDIR/meta/supported). Skipping support check.${REG}"
        fi
    else 
        local SUPPORTEDARR=($(echo "$SUPPORTED" | tr ',' '\n'))
        if ! (printf '%s\n' "${SUPPORTEDARR[@]}" | grep -q -P "$PVEVersionMajor"); then
            echo -e "${WARN}You might encounter issues because your version ($PVEVersionMajor) is not matching currently supported versions ($SUPPORTED)."
            echo -e "If you do run into any issues on >newer< versions, please consider opening an issue at https://github.com/codding-nepale/PVEDiscordThemeRemake/issues.${REG}"
        fi
    fi
}

#endregion Helper functions

#region Main functions
function usage {
    if [ "$_silent" = false ]; then
        echo -e "Usage: $0 [OPTIONS...] {COMMAND}\n"
        echo -e "Manages the PVEDiscordThemeRemake theme."
        echo -e "  -h --help            Show this help"
        echo -e "  -s --silent          Silent mode\n"
        echo -e "Commands:"
        echo -e "  status               Check current theme status (returns 0 if installed, and 1 if not installed)"
        echo -e "  install              Install the theme"
        echo -e "  uninstall            Uninstall the theme"
        echo -e "  update               Update the theme (runs uninstall, then install)"
    #    echo -e "  utility-update       Update this utility\n" (to be implemented)
        echo -e "Exit status:"
        echo -e "  0                    OK"
        echo -e "  1                    Failure"
        echo -e "  2                    Already installed, OR not installed (when using install/uninstall commands)\n"
        echo -e "Report issues at: <https://github.com/codding-nepale/PVEDiscordThemeRemake/issues>"
    fi
}

function status {
    if [ "$_silent" = false ]; then
        echo -e "Theme"
        echo -e "  CSS:         $(sha256sum /usr/share/javascript/proxmox-widget-toolkit/themes/theme-proxmox-discord-dark.css 2>/dev/null  || echo N/A)"
        echo -e "  JS:          $(sha256sum /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js 2>/dev/null  || echo N/A)\n"
        echo -e "PVE"
        echo -e "  Version:     $PVEVersion (major $PVEVersionMajor)\n"
        echo -e "Utility hash:  $(sha256sum $SCRIPTPATH 2>/dev/null  || echo N/A)"
        echo -e "Offline mode:  $OFFLINE"
    fi
}

function install {
    if [ "$_silent" = false ]; then echo -e "${GRN}Installing theme${REG}"; fi
    if [ -f /usr/share/javascript/proxmox-widget-toolkit/themes/theme-proxmox-discord-dark.css ]; then
        cp /usr/share/javascript/proxmox-widget-toolkit/themes/theme-proxmox-discord-dark.css /usr/share/javascript/proxmox-widget-toolkit/themes/theme-proxmox-discord-dark.css.bak
    fi
    if [ -f /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js ]; then
        cp /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js.bak
    fi
    if [ -d /usr/share/javascript/proxmox-widget-toolkit/images ]; then
        cp -r /usr/share/javascript/proxmox-widget-toolkit/images /usr/share/javascript/proxmox-widget-toolkit/images.bak
    fi
    if [ "$OFFLINE" = false ]; then
        curl -s $BASE_URL/PVEDiscordTheme/css/theme-proxmox-discord-dark.css > /usr/share/javascript/proxmox-widget-toolkit/themes/theme-proxmox-discord-dark.css
        curl -s $BASE_URL/PVEDiscordTheme/js/proxmoxlib.js > /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
        if [ -d "/usr/share/javascript/proxmox-widget-toolkit/images" ]; then
            rm -rf /usr/share/javascript/proxmox-widget-toolkit/images
        fi
        $old_cwd=$(pwd)
        cd /usr/share/javascript/proxmox-widget-toolkit && wget -q https://github.com/codding-nepale/PVEDiscordThemeRemake/raw/main/PVEDiscordTheme/images/images.zip
        if [ -x "$(command -v unzip)" ]; then
            unzip -q images.zip
            rm images.zip
        else
            apt-get install unzip -y -qq
            unzip -q images.zip
            rm images.zip
            apt-get purge unzip -y -qq
        fi
        cd $old_cwd
    fi
    if [ "$_silent" = false ]; then echo -e "${GRN}Theme installed${REG}"; fi
}

function uninstall {
        if [ "$_silent" = false ]; then echo -e "${GRN}Uninstalling theme${REG}"; fi
        rm -rf /usr/share/javascript/proxmox-widget-toolkit/themes/theme-proxmox-discord-dark.css
        if [ -f /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js.bak ]; then
            mv /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js.bak /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
        else
            echo -e "${RED}Warning: ${REG}Could not find backup of proxmoxlib.js. Please check if the file /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js exists and contains the original proxmoxlib.js."
            $failed_proxmoxlib=true
        fi
        if [ -d /usr/share/javascript/proxmox-widget-toolkit/images.bak ]; then
            rm -rf /usr/share/javascript/proxmox-widget-toolkit/images
            mv /usr/share/javascript/proxmox-widget-toolkit/images.bak /usr/share/javascript/proxmox-widget-toolkit/images
        else
            echo -e "${RED}Warning: ${REG}Could not find backup of images folder. Please check if the folder /usr/share/javascript/proxmox-widget-toolkit/images exists and contains the original images."
            $failed_images=true
        fi
        if [ $failed_proxmoxlib = true ] || [ $failed_images = true ]; then
            echo -e "${RED}Uninstall completed with error${REG}"
            if [ $failed_proxmoxlib = true ]; then
                echo -e "${RED}proxmoxlib.js${REG} could not be restored. Please check if the file /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js exists and contains the original proxmoxlib.js."
            fi
            if [ $failed_images = true ]; then
                echo -e "${RED}images folder${REG} could not be restored. Please check if the folder /usr/share/javascript/proxmox-widget-toolkit/images exists and contains the original images."
            fi
        fi
        if [ $failed_proxmoxlib = true ] && [ $failed_images = true ]; then
            echo -e "${RED}Uninstall failed${REG}"
            exit 1
        fi
        if [ "$_silent" = false ]; then echo -e "${GRN}Theme uninstalled${REG}"; fi
}

#endregion Main functions

_silent=false
_command=false
_noexit=false

parse_cli()
{
	while test $# -gt -0
	do
		_key="$1"
		case "$_key" in
			-h|--help)
				usage
				exit 0
				;;
            -s|--silent)
                _silent=true
                ;;
            status) 
                if [ "$_command" = false ]; then
                    _command=true
                    status
                fi
                ;;
            install) 
                if [ "$_command" = false ]; then
                    _command=true
                    install
                    exit 0
                fi
                ;;
            uninstall)
                if [ "$_command" = false ]; then
                    _command=true
                    uninstall
                    exit 0
                fi
                ;;
            update)
                if [ "$_command" = false ]; then
                    _command=true
                    _noexit=true
                    uninstall
                    install
                    exit 0
                fi
                ;;
	     *)
				echo -e "${BRED}Error: Got an unexpected argument \"$_key\"${REG}\n"; 
                usage;
                exit 1;
				;;
		esac
		shift
	done
}

parse_cli "$@"
=
