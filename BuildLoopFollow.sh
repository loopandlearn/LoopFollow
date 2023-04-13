# !/bin/bash

BUILD_DIR=~/Downloads/BuildLoopFollow
OVERRIDE_FILE=ConfigOverride.xcconfig
OVERRIDE_FULLPATH="${BUILD_DIR}/${OVERRIDE_FILE}"
DEV_TEAM_SETTING_NAME="LF_DEVELOPMENT_TEAM"

## Unmodified code from Loop build_functions.sh for constistancy - BEGIN
RED='\033[0;31m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

function exit_message() {
    section_divider
    echo -e "\nShell Script Completed\n"
    echo -e " * You may close the terminal window now if you want"
    echo -e "   or"
    echo -e " * You can press the up arrow ⬆️  on the keyboard"
    echo -e "    and return to repeat script from beginning.\n\n"
    exit 0
}

function section_separator() {
    clear
    echo -e "--------------------------------\n"
}

function section_divider() {
    echo -e "--------------------------------\n"
}

function return_when_ready() {
    echo -e "${RED}${BOLD}Return when ready to continue${NC}"
    read -p "" dummy
}

function cancel_entry() {
    echo -e "\n${RED}${BOLD}User canceled${NC}\n"
    exit_message
}

function invalid_entry() {
    echo -e "\n${RED}${BOLD}User canceled by entering an invalid option${NC}\n"
    exit_message
}

function choose_or_cancel() {
    echo -e "\nType a number from the list below and return to proceed."
    echo -e "${RED}${BOLD}  To cancel, any entry not in list also works${NC}"
    echo -e "\n--------------------------------\n"
}

function how_to_find_your_id() {
    echo -e "Your Apple Developer ID is the 10-character Team ID"
    echo -e "  found on the Membership page after logging into your account at:"
    echo -e "   https://developer.apple.com/account/#!/membership\n"
    echo -e "It may be necessary to click on the Membership Details icon"
}

function clone_download_error_check() {
    # indicate that a clone was created
    CLONE_OBTAINED=1
    echo -e "--------------------------------\n"
    echo -e "🛑 Check for successful Download\n"
    echo -e "   Please scroll up and look for the word ${BOLD}error${NC} in the window above."
    echo -e "   OR use the Find command for terminal, hold down CMD key and tap F,"
    echo -e "      then type error (in new row, top of terminal) and hit return"
    echo -e "      Be sure to click in terminal again if you use CMD-F"
    echo -e "   If there are no errors listed, code has successfully downloaded, Continue."
    echo -e "   If you see the word error in the download, Cancel and resolve the problem."
    choose_or_cancel
}
## Unmodified code from Loop build_functions.sh for constistancy - END

## Modified code from Loop build_functions.sh that should be backward compatible - BEGIN
function report_persistent_config_override() {
    echo -e "The file used by Xcode to sign your app is found at:"
    echo -e "   ${OVERRIDE_FULLPATH}"
    echo -e "   The line containing the team id is shown next:"
    grep "^$DEV_TEAM_SETTING_NAME" ${OVERRIDE_FULLPATH}
    echo -e "\nIf the line has your Apple Developer ID"
    echo -e "   your target(s) will be automatically signed"
    echo -e "WARNING: Any line that starts with // is ignored\n"
    echo -e "  If ID is not OK:"
    echo -e "    Edit the ${OVERRIDE_FILE} before hitting return"
    echo -e "     step 1: open finder, navigate to "${BUILD_DIR#*Users/*/}""
    echo -e "     step 2: locate and double click on "${OVERRIDE_FILE}""
    echo -e "             this will open that file in Xcode"
    echo -e "     step 3: edit in Xcode and save file\n"
    echo -e "  If ID is OK, hit return"
    return_when_ready
}
## Modified code from Loop build_functions.sh that should be backward compatible - END

set_development_team() {
    team_id="$1"
    echo "$DEV_TEAM_SETTING_NAME = $team_id" >> ${OVERRIDE_FULLPATH}
}

function check_config_override_existence_offer_to_configure() {
    section_separator

    # Automatic signing functionality:
    # 1) Use existing LoopFollow team
    # 2) Copy team from Loop
    # 3) Copy team from latest provisioning profile
    # 4) Enter team manually with option to skip
    if [ -f ${OVERRIDE_FULLPATH} ] && grep -q "^$DEV_TEAM_SETTING_NAME" ${OVERRIDE_FULLPATH}; then
        how_to_find_your_id
        report_persistent_config_override
    else
        if [ -f "../../BuildLoop/LoopConfigOverride.xcconfig" ] && grep -q '^LOOP_DEVELOPMENT_TEAM' "../../BuildLoop/LoopConfigOverride.xcconfig"; then
            echo -e "Using existing LOOP_DEVELOPMENT_TEAM setting\n"
            DEVELOPMENT_TEAM=$(grep '^LOOP_DEVELOPMENT_TEAM' "../../BuildLoop/LoopConfigOverride.xcconfig" | awk '{print $3}')
            set_development_team "$DEVELOPMENT_TEAM"
            how_to_find_your_id
            report_persistent_config_override
        else
            PROFILES_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"

            if [ -d "${PROFILES_DIR}" ]; then
                latest_file=$(find "${PROFILES_DIR}" -type f -name "*.mobileprovision" -print0 | xargs -0 ls -t | head -n1)
                if [ -n "$latest_file" ]; then
                    # Decode the .mobileprovision file using the security command
                    decoded_xml=$(security cms -D -i "$latest_file")

                    # Extract the Team ID from the XML
                    DEVELOPMENT_TEAM=$(echo "$decoded_xml" | awk -F'[<>]' '/<key>TeamIdentifier<\/key>/ { getline; getline; print $3 }')
                fi
            fi

            if [ -n "$DEVELOPMENT_TEAM" ]; then
                echo -e "Using TeamIdentifier from the latest provisioning profile\n"
                set_development_team "$DEVELOPMENT_TEAM"
                how_to_find_your_id
                report_persistent_config_override
            else
                echo -e "Choose 1 to Sign Automatically or "
                echo -e "       2 to Sign Manually (later in Xcode)"
                echo -e "\nIf you choose Sign Automatically, script guides you"
                echo -e "  to create a permanent signing file"
                echo -e "  containing your Apple Developer ID"
                choose_or_cancel
                options=("Sign Automatically" "Sign Manually" "Cancel")
                select opt in "${options[@]}"
                do
                    case $opt in
                        "Sign Automatically")
                            create_persistent_config_override
                            break
                            ;;
                        "Sign Manually")
                            break
                            ;;
                        "Cancel")
                            cancel_entry
                            ;;
                        *) # Invalid option
                            invalid_entry
                            ;;
                    esac
                done
            fi            
        fi
    fi
}

function create_persistent_config_override() {
    section_separator
    echo -e "The Apple Developer page will open when you hit return\n"
    how_to_find_your_id
    echo -e "That page will be opened for you."
    echo -e "  Once you get your ID, you will enter it in this terminal window"
    return_when_ready
    #
    open "https://developer.apple.com/account/#!/membership"
    echo "Please click in terminal window and enter your Apple Developer Team ID (10 characters) or press Enter to skip:"
    while true; do
        read DEVELOPMENT_TEAM
        if [ -z "$DEVELOPMENT_TEAM" ]; then
            echo -e "You can manually sign target(s) in Xcode"
            break
        elif [ ${#DEVELOPMENT_TEAM} -eq 10 ]; then
            set_development_team "$DEVELOPMENT_TEAM"
            break
        else
            echo "Invalid Team ID. Please enter a valid 10-character Team ID or press Enter to skip."
        fi
    done
    #
    section_separator
}

# Check if a argument is provided for the repo
if [ "$#" -ge 1 ]; then
  REPO="$1"
else
  REPO="https://github.com/jonfawcett/LoopFollow"
fi

# Check if a second argument is provided for the branch
if [ "$#" -ge 2 ]; then
  CUSTOM_BRANCH="$2"
fi

if [ "$#" -ge 1 ]; then
  echo "[DEBUG] Repo URL: $REPO"
    if [ -n "$CUSTOM_BRANCH" ]; then
        echo "[DEBUG] Custom Branch: $CUSTOM_BRANCH"
    fi
    return_when_ready
fi

section_separator
echo -e "Welcome to Loop Follow.\nThis script will assist you in downloading and building the app.\nBefore you begin, please ensure that you have Xcode installed and your phone is plugged into your computer\n"
echo -e "Type 1 and hit enter to begin.\nType 2 and hit enter to cancel."
choose_or_cancel
options=("Continue" "Cancel")
select opt in "${options[@]}"
do
    case $opt in
        "Continue")
            break
            ;;
        "Cancel")
            cancel_entry
            ;;
        *)
            invalid_entry
            ;;        
    esac
done

if [ -z "$CUSTOM_BRANCH" ]; then
    section_separator
    echo -e "Please select which version of Loop Follow you would like to download and build.\nDev branch has the latest features but may contain more bugs.\n\nType the number 1 or 2 and hit enter to select the branch.\nType 3 and hit enter to cancel.\n"
    choose_or_cancel
    options=("Main Branch" "Dev Branch" "Cancel")
    select opt in "${options[@]}"
    do
        case $opt in
            "Main Branch")
                FOLDERNAME=LoopFollow-Main
                BRANCH=Main
                break
                ;;
            "Dev Branch")
                FOLDERNAME=LoopFollow-Dev
                BRANCH=dev
                break
                ;;
            "Cancel")
                cancel_entry
                ;;
            *)
                invalid_entry
                ;;        
        esac
    done
else
  BRANCH="$CUSTOM_BRANCH"
  FOLDERNAME="LoopFollow-$BRANCH"
fi

section_separator
echo -e "Would you like to delete prior downloads of Loop Follow before proceeding?\n"
echo -e "Type 1 and hit enter to delete.\nType 2 and hit enter to continue without deleting"
choose_or_cancel
options=("Delete old downloads" "Do not delete old downloads" "Cancel")
select opt in "${options[@]}"
do
    case $opt in
        "Delete old downloads")
            # Delete all folders below ~/Downloads/BuildLoopFollow but preserve ConfigOverride.xcconfig
            find ~/Downloads/BuildLoopFollow -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +
            break
            ;;
        "Do not delete old downloads")
            break
            ;;
        "Cancel")
            cancel_entry
            ;;
        *)
            invalid_entry
            ;; 
    esac
done

section_separator
echo -e "The code will now begin downloading.\nThe files will be saved in your Downloads folder.\n"
echo -e "Type 1 and hit enter to begin downloading.\nType 2 and hit enter to cancel.\n"
choose_or_cancel
options=("Continue" "Cancel")
select opt in "${options[@]}"
do
    case $opt in
        "Continue")
            break
            ;;
        "Cancel")
            cancel_entry
            ;;
        *)
            invalid_entry
            ;; 
    esac
done

section_separator
LOOP_BUILD=$(date +'%y%m%d-%H%M')
LOOP_DIR=~/Downloads/BuildLoopFollow/$FOLDERNAME-$LOOP_BUILD
mkdir -p $LOOP_DIR
cd $LOOP_DIR

echo -e "Downloading Loop Follow to your Downloads folder."
pwd
echo -e
git clone --branch=$BRANCH --recurse-submodules $REPO
clone_download_error_check
options=("Continue" "Cancel")
select opt in "${options[@]}"
do
    case $opt in
        "Continue")
            break
            ;;
        "Cancel")
            cancel_entry
            ;;
        *)
            invalid_entry
            ;;
    esac
done

check_config_override_existence_offer_to_configure

section_separator
echo -e "Type 1 and hit enter to open Xcode. You may close the terminal after Xcode opens"
choose_or_cancel
options=("Continue" "Cancel")
select opt in "${options[@]}"
do
    case $opt in
        "Continue")
            break
            ;;
        "Cancel")
            cancel_entry
            ;;
        *)
            invalid_entry
            ;;
    esac
done

cd LoopFollow
Echo Open xcode
xed ./LoopFollow.xcworkspace
exit
