# !/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'
REPO=https://github.com/jonfawcett/LoopFollow

clear
echo -e "\n\n--------------------------------\n\nWelcome to Loop Follow. This script will assist you in downloading and building the app. Before you begin, please ensure that you have Xcode installed and your phone is plugged into your computer\n\n--------------------------------\n\n"
echo -e "Type 1 and hit enter to begin.\nType 2 and hit enter to cancel."
options=("Continue" "Cancel")
select opt in "${options[@]}"
do
    case $opt in
        "Continue")
            break
            ;;
        "Cancel")
            echo -e "\n${RED}User cancelled!${NC}";
            exit 0
            break
            ;;
        *)
    esac
done

clear

echo -e "Please select which version of Loop Follow you would like to download and build. Dev branch has the latest features but may contain more bugs.\n\nType the number 1 or 2 and hit enter to select the branch.\nType 3 and hit enter to cancel.\n\n"
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
            echo -e "\n${RED}User cancelled!${NC}";
            exit 0
            break
            ;;
        *) 
    esac
done

clear
echo -e "Would you like to delete prior downloads of Loop Follow before proceeding?\n\n"
echo -e "Type 1 and hit enter to delete.\nType 2 and hit enter to continue without deleting.\n\n"
options=("Delete old downloads" "Do not delete old downloads")
select opt in "${options[@]}"
do
    case $opt in
        "Delete old downloads")
            rm -rf ~/Downloads/BuildLoopFollow/*
            break
            ;;
        "Do not delete old downloads")
            break
            ;;
        *)
    esac
done

clear
echo -e "The code will now begin downloading. The files will be saved in your Downloads folder and Xcode will automatically open when the download is complete.\n\n"
echo -e "Type 1 and hit enter to begin downloading.\nType 2 and hit enter to cancel.\n\n"
options=("Continue" "Cancel")
select opt in "${options[@]}"
do
    case $opt in
        "Continue")
            break
            ;;
        "Cancel")
            echo -e "\n${RED}User cancelled!${NC}";
            exit 0
            break
            ;;
        *)
    esac
done

clear

LOOP_BUILD=$(date +'%y%m%d-%H%M')
LOOP_DIR=~/Downloads/BuildLoopFollow/$FOLDERNAME-$LOOP_BUILD
mkdir ~/Downloads/BuildLoopFollow/
mkdir $LOOP_DIR
cd $LOOP_DIR
pwd
clear
echo -e "\n\n Downloading Loop Follow.\n--------------------------------\n"
git clone --branch=$BRANCH --recurse-submodules $REPO

echo -e "--------------------------------\n\nIf there are no errors listed above, code has successfully downloaded.\n"
echo -e "Type 1 and hit enter to open Xcode. You may close the terminal after Xcode opens\n\n"

options=("Continue" "Cancel")
select opt in "${options[@]}"
do
    case $opt in
        "Continue")
            break
            ;;
        *)
    esac
done


cd LoopFollow
Echo Open xcode
xed .
exit
