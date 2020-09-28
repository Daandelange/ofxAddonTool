#!/bin/bash

# ofxAddonTool is a dependency manager for OpenFrameworks projects.
# It works together with an addons.txt as config file.

# - - - -
# MIT License
#
# Copyright (c) 03-2020 Daan de Lange - https://daandelange.com/
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# - - - - - - -


# SCRIPT NOTES
# Various lines are left commented, lots of alternative ways or debug helpers.
# Keep them until we've tested this on multiple platforms and setups.
# There's also a lot of comments on Bash code, to make it more understandable for me and for other C++ programers.

#set -ex # <-- useful for debugging, shows the lines being executed during execution
#set -e  # <-- Stop script on any error

VERSION_NUMBER="0.2_alpha";

# Terminal color definitions
style_red=$(tput setaf 1)
style_green=$(tput setaf 2)
style_yellow=$(tput setaf 3)
style_reset=$(tput sgr 0)

# Parse parameters / options
USER_ACTION="";
INTERACTIVE=1;
SHOW_INTRO=1;
for arg in "$@"; do
  if [[ -z "$USER_ACTION" ]]; then # Ignores actions when another is already defined.
    if [ "$arg" = "--install" ]; then
      USER_ACTION="install";
    elif [ "$arg" = "--check" ]; then
      USER_ACTION="check";
    elif [ "$arg" = "--update" ]; then
      USER_ACTION="update";
    elif [ "$arg" = "--sync" ]; then
      USER_ACTION="sync";
    elif [ "$arg" = "--help" ]; then
      USER_ACTION="help";
    fi
  fi
  if [ "$arg" = "--yes" ]; then
    INTERACTIVE=0;
  elif [ "$arg" = "--no-intro" ]; then
    SHOW_INTRO=0;
  fi
done

# No options ? Ask user what to do
if [[ "$INTERACTIVE" -eq 1 && -z "$USER_ACTION" ]]; then
  echo   "Which action would you like to perform ? (please type a number)";
  echo   "             1. Check addon status. (default)";
  echo   "             2. Install addon dependencies.";
  echo   "             3. Update addon dependencies.";
  echo   "             4. Syncronize addons.txt with addons.make.";
  echo   "             5. Show help.";
  #echo   "             6. Selfupdate : update ofxAddonTool.";
  printf "Your choice: " && read -r answer;
  
  if [[ "$answer" -eq "1" ]]; then
    USER_ACTION="check";
  elif [[ "$answer" -eq "2" ]]; then
    USER_ACTION="install";
  elif [[ "$answer" -eq "3" ]]; then
    USER_ACTION="update";
  elif [[ "$answer" -eq "4" ]]; then
    USER_ACTION="sync";
  elif [[ "$answer" -eq "5" ]]; then
    USER_ACTION="help";
  fi
fi

# Print HELP ?
if [ "$USER_ACTION" = "help" ]; then
  if [[ `figlet "."` && $? -eq 0 ]]; then
    # Figlet is installed
    figlet -w "$(tput cols)" -f big "ofxAddonTool"; # -t doesn't work on OSX. Using -w instead
  elif [[ `toilet "."` && $? -eq 0 ]]; then
    # Toilet is installed
    toilet -t -f big "ofxAddonTool";
  else
    # No ascii art tool is installed
    #echo "ofxAddonTool";
    echo "        __                   _     _          _______          _ ";
    echo "       / _|         /\      | |   | |        |__   __|        | |";
    echo "  ___ | |___  __   /  \   __| | __| | ___  _ __ | | ___   ___ | |";
    echo " / _ \|  _\ \/ /  / /\ \ / _\` |/ _\` |/ _ \| '_ \| |/ _ \ / _ \| |";
    echo "| (_) | |  >  <  / ____ \ (_| | (_| | (_) | | | | | (_) | (_) | |";
    echo " \___/|_| /_/\_\/_/    \_\__,_|\__,_|\___/|_| |_|_|\___/ \___/|_|";
    echo "                                                                 ";
  fi
  
  echo "An utility for managing OpenFrameworks addon dependencies for a given project."
  echo "Version ${VERSION_NUMBER}";
  echo "";
  echo "Usage: ofxAddonTool.sh [--yes] [--no-intro] --ACTION";
  echo "";
  echo "--ACTION      Action to perform :";
  echo "     --check    Shows the current stat of your OpenFrameworks' addon folder.";
  echo "     --install  Installs the required addons. (ignores if already installed)"
  echo "     --update   Tries to pull remote changes, if any are available. (only if your local branch is clean)"
  echo "     --sync     Synchronizes with addons.make using the config from addons.txt"
  echo "     --help     Shows the current status of your OpenFrameworks' addon folder."
  echo "";
  echo "Optional arguments :";
  echo "     --yes      Disable user interactions (for scripts).";
  echo "     --no-intro Don't show the intro banner.";
  echo "";
  exit 0;
fi # Endif HELP

# Get project information
curDir=`pwd`;
repoDiagnosticMessage="";
#repoName= basename `git rev-parse --show-toplevel`;
repoName=$( basename "$curDir" );

# Check if we have a git repo
if [ ! -d "$curDir/.git" ]; then
  echo "${style_red}ERROR: $curDir is not a git repository!${style_reset}";
  exit 1;
fi

# Check for updates
git fetch --quiet > /dev/null 2>&1 # Hides output as --quiet doesn't silence git fatal errors such as no internet.
let projectRemoteUnavailable=$? # keep this line directly after to git fetch
#if [ "$projectRemoteUnavailable" -gt 0 ]; then
if [ "$projectRemoteUnavailable" -gt 0 ]; then
  repoDiagnosticMessage+="${style_red}Warning: Could not fetch updates.${style_reset} ";
fi

if [[ ! -z `git status --porcelain` ]]; then
  repoDiagnosticMessage+="${style_yellow}Your branch has local changes.${style_reset} ";
fi

if [[ ! -z `git log ..@{u}` ]]; then
  repoDiagnosticMessage+="${style_yellow}New comits are available.${style_reset} ";
fi


# Locate the addons folder
#cd "$curDir"
cd ../../../addons >> /dev/null 2>&1 ; #silenced
if [[ $? -gt 0 ]]; then
  echo "${style_red}ERROR : the addons folder was not found.${style_reset}"
  exit 1;
fi
addonsDir=`pwd`
cd "$curDir"


# Show intro banner
if [ "$SHOW_INTRO" -eq 1 ]; then
  # Say hello
  echo ""
  echo "Hello, this script will scan your addons folder and check if all the necessary addons are correctly installed."
  echo "If some fields are marked yellow/red, they might need manual attention."
  echo "This script is in beta phase. Only tested on osx and linux for now."
  echo ""
  
  # Print some repository information
  if [[ `figlet "."` && $? -eq 0 ]]; then
    # Figlet is installed
    figlet -f basic "$repoName";
  elif [[ `toilet "."` && $? -eq 0 ]]; then
    # Figlet is installed
    toilet -f basic "$repoName";
  else
    # No ascii art tool is installed
    echo "Project    : $repoName";
  fi

  echo "Path       : $curDir";
  if [[ ! -z "$repoDiagnosticMessage" ]]; then
    echo "Diagnotsic : $repoDiagnosticMessage";
  else
    echo "Diagnotsic : ${style_green}The base repo is clean.${style_reset}";
  fi
  echo " "
  echo "Addons configuration file : $curDir/addons.txt";
  echo "Detected addons directory : $addonsDir";
  echo " "
  #echo "Working from $repoName";
fi # end show intro banner

# Set default action
if [[ -z "$USER_ACTION" ]]; then
  USER_ACTION="check";
  echo "${style_yellow}Warning: Unrecognized script action. Continueing with default behaviour \"${USER_ACTION}\".${style_reset}";
else
  echo "Starting addons action: $USER_ACTION";
fi
echo "";



# Sync with addons.make ?
if [ "$USER_ACTION" = "sync" ]; then
  echo "Syncing is not implemented yet. Bye.";
  exit 0;
fi

# Table formatting
# Column widths are set proportionally to the available terminal width
let availableWidth=`tput cols`; # in characters (not pixels)
let availableWidth=$availableWidth-5; # removes 5 column separators
# Values scale : 0=0% width, 1.0 is 100% width
# Rule : nb_cols*col_width + nb_cols2*col2_width + ... = 1.0
let COL_TINY=$(echo "scale=0; ($availableWidth * 0.04) / 1" | bc );
let COL_SMALL=$(echo "scale=0; ($availableWidth * 0.10) / 1" | bc );
let COL_MEDIUM=$(echo "scale=0; ($availableWidth * 0.14) / 1" | bc );
COL_LARGE=$(echo "scale=0; ($availableWidth * 0.22) / 1" | bc );

PRINTF_TABLE_LINE="%-${COL_MEDIUM}.${COL_MEDIUM}s | %-${COL_LARGE}.${COL_LARGE}s | %-${COL_SMALL}.${COL_SMALL}s | %-${COL_SMALL}.${COL_SMALL}s | %-${COL_MEDIUM}.${COL_MEDIUM}s | %-${COL_LARGE}.${COL_LARGE}s \n";

# Table header
printf "$PRINTF_TABLE_LINE" "- - - - - - - - - - - - - - - - - - - - " "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - " "- - - - - - - - - - - - - - - - " "- - - - - - - - - - - - - - - - " "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - " "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - "
#printf "%-30s | %-50s | %-16s | %-16s | %-16s | %-16s | %-16s \n" "Addon" "Required Repo" "Needed Branch" "Exists" "Remote URL" "Local Branch" "Local Changes"
printf "$PRINTF_TABLE_LINE" "Addon" "Required Repo" "Needed Branch" "Local Branch" "Tracking target" "Diagnostic"
printf "$PRINTF_TABLE_LINE" "- - - - - - - - - - - - - - - - - - - - " "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - " "- - - - - - - - - - - - - - - - " "- - - - - - - - - - - - - - - - " "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - " "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - "

exit 0; #tmp

# This function receives a line with the following format : NAME URL BRANCH
# Called for each addon in addons.txt
function processAddon {
  # parse arguments
  local addonName=$(echo $addon | cut -f1 -d' ')
  local addonUrl=$(echo $addon | cut -f2 -d' ')
  local addonBranch=$(echo $addon | cut -f3 -d' ')

  # define vars
  local addonRemoteUrl=''
  local addonTrackingRemote=''
  local addonLocalBranch=''

  # default return values
  local addonExists='-'
  local addonExistsCol=$style_red
  local addonRemoteIsSame='-'
  local addonRemoteIsSameCol=$style_reset
  #addonBranchIsSame='-different-'
  local addonBranchIsSameCol=$style_reset
  local addonHasLocalChanges='-'
  #addonHasLocalChangesCol=$style_normal
  local addonDiagnosticMessage=""
  local addonDiagnosticMessageCol=$style_reset

  # check id addon directory exists
  if [ -d "$addonsDir/$addonName" ]; then
    local addonExists='yes'
    local addonExistsCol=$style_green

    cd $addonsDir/$addonName

    # Parse local information
    local addonLocalBranch=`git name-rev --name-only HEAD` # ex: master (local branch name)
    local addonTrackingRemote=`git config branch.$addonLocalBranch.remote` # ex: origin (remote's local name)
    #local addonRemoteUrl=$(git config remote.$addonTrackingRemote.url) # ex: https://github.com/armadillu/ofxTimeMeasurements
    local addonRemoteUrl=$(git remote get-url $addonTrackingRemote) # alternative for the above line
    #local addonRemoteTrackingBranch=$(git rev-parse --symbolic-full-name --abbrev-ref $addonTrackingRemote) # ex: origin/master # Note: I got some unexpected values for some repos. Better not use.
    local addonRemoteTrackingBranch=$(git rev-parse --symbolic-full-name --abbrev-ref $addonLocalBranch@{upstream}) # ex: origin/master (long version)
    #local addonRemoteTrackingBranch=$(git symbolic-ref --quiet --short HEAD) # ex: master (short version)
    
    # Check for a detached head / tracking repo
    local dummyvar=$(git symbolic-ref --quiet --short HEAD) # quiet command, we use the exit code via $?
    #dummyvar=(git symbolic-ref --quiet --short no_branch_like_this); # Debug, uncomment to send exit code 1 to $?
    let addonHasDetachedHead=$? # keeps exit status of previous command. (keep this line after the previous one)
    #addonDetachedHead=$(git rev-parse --abbrev-ref HEAD) #ex: master, if tracking. Hash otherwise.
    
    #addonRemoteTrackingBranch=`git config branch.$addonLocalBranch.merge` #ex : refs/heads/master
    #addonRemoteTrackingBranch=`git symbolic-ref -q HEAD` #ex : refs/heads/master, exit code indicates tracking status.

    #echo "Current branch remote.name = $(git rev-parse --abbrev-ref HEAD)" # ex: master
    #echo "Entering ${mosaic_addons[$i]} @ $(git status -b -s)";
    #TRACKING_BRANCH=`git config branch.$LOCAL_BRANCH.merge` # ex: refs/heads/master

    # Check if remote URL is the same
    if [[ "$addonRemoteUrl" =~ ${addonUrl//https?\:\/\//} ]]; then
      #addonRemoteIsSame='ok'
      #addonRemoteIsSameCol=$style_green
      #addonDiagnosticMessageCol=$style_green

      # Local branch name can be different. Mark green when it's the same.
      if [[ "$addonLocalBranch" =~ $addonBranch ]]; then
        addonBranchIsSameCol=$style_green
      else
        addonBranchIsSameCol=$style_yellow
      fi

      # Check if the local branch tracks the right branch
      if [[ "$addonTrackingRemote/$addonBranch" =~ "$addonRemoteTrackingBranch" ]]; then
        #addonBranchIsSame="$addonLocalBranch"
        #addonBranchIsSameCol=$style_green
        addonRemoteIsSameCol=$style_green

        # Sync with remote(s), updates references
        # maybe use this instead ? : git remote update
        git fetch --quiet > /dev/null 2>&1 # Hides output as --quiet doesn't silence git fatal errors such as no internet.

        # Check for network errors
        let addonRemoteUnavailable=$? # keep this line directly after to git fetch

        # Check for available updates (quick method)
        lastLocalCommit=`git show --no-notes --format=format:"%H" "$addonBranch" | head -n 1`
        lastRemoteCommit=`git show --no-notes --format=format:"%H" "$addonTrackingRemote/$addonBranch" | head -n 1`
        if [ "$lastLocalCommit" != "$lastRemoteCommit" ]; then
          addonDiagnosticMessage="New commits are available, please pull this repo."
          addonDiagnosticMessageCol=$style_yellow
          addonBranchIsSameCol=$style_yellow
        else

          # Check for diffs (uncomited local changes) (or rather differences with remote ?)
          #if [[ `git diff --cached --name-only $addonLocalBranch $addonTrackingRemote/$addonBranch` ]]; then # --cached includes uncomited changes
          if [[ ! -z `git status "--untracked-files=no" "--porcelain"` ]]; then
            addonDiagnosticMessage="This repo has uncomited local changes."
            addonDiagnosticMessageCol=$style_yellow
          fi

        fi
        # Remote unreachable
        if [ "$addonRemoteUnavailable" -gt 0 ]; then
          if [ -z "$addonDiagnosticMessage" ]; then #only set message if not already set
            addonDiagnosticMessage="The remote is unreachable."
            addonDiagnosticMessageCol=$style_yellow
          fi
        fi

      # Incorrect tracking branch
      else
        #echo "Mismatch : $addonLocalBranch is not $addonBranch"
        #echo "$addonTrackingRemote/$addonBranch VS $addonRemoteTrackingBranch"
        addonRemoteIsSameCol=$style_red
        addonDiagnosticMessage="Your local branch tracks a different branch."
        addonDiagnosticMessageCol=$style_red
        #addonBranchIsSame="/!\ $addonLocalBranch"
      fi

    else
      addonDiagnosticMessage="Your local branch tracks a different repo/url."
      addonDiagnosticMessageCol=$style_red
      addonRemoteIsSameCol=$style_red
      addonBranchIsSameCol=$style_yellow
    fi

    # warn for detached head ? (override other info for GUI only)
    if [ "$addonHasDetachedHead" -gt 0 ]; then
      addonRemoteIsSameCol=$style_yellow
      addonRemoteTrackingBranch="Detached head"
      if [ -z "$addonDiagnosticMessage" ]; then #only set message if not already set
        addonDiagnosticMessageCol=$style_red
        addonDiagnosticMessage="This local branch is not tracking any remote branch."
      fi
    fi

  else
    addonDiagnosticMessageCol=$style_red
    addonDiagnosticMessage="This addon is not installed."
    addonBranchIsSameCol=$style_red
    addonLocalBranch="-not installed-"
  fi

  # output table line with info
  #printf " %-30s | %-30s |" "$addonName" "$addonUrl"
  #printf "%-30s | %-50s | %-16s | ${addonExistsCol}%-16s${style_reset} | ${addonRemoteIsSameCol}%-16s${style_reset} | ${addonBranchIsSameCol}%-16s${style_reset} | ${addonHasLocalChangesCol}%-16s${style_reset} | %-16s " "$addonName" "$addonUrl" "$addonBranch" "$addonExists" "$addonRemoteIsSame" "$addonBranchIsSame" "$addonHasLocalChanges"
  
  #printf "%-20s | %-40s | %-16s | ${addonBranchIsSameCol}%-16s${style_reset} | ${addonRemoteIsSameCol}%-16s${style_reset} | ${addonDiagnosticMessageCol}%-16s${style_reset} " "${addonName:0:16}" "${addonUrl/https:\/\//}" "$addonBranch" "$addonLocalBranch" "$addonRemoteTrackingBranch" "$addonDiagnosticMessage"
  local PRINTF_TABLE_LINE_COLORED="%-${COL_MEDIUM}.${COL_MEDIUM}s | %-${COL_LARGE}.${COL_LARGE}s | %-${COL_SMALL}.${COL_SMALL}s | ${addonBranchIsSameCol}%-${COL_SMALL}.${COL_SMALL}s${style_reset} | ${addonRemoteIsSameCol}%-${COL_MEDIUM}.${COL_MEDIUM}s${style_reset} | ${addonDiagnosticMessageCol}%s${style_reset} \n";
  printf "$PRINTF_TABLE_LINE_COLORED"  "${addonName}" "${addonUrl/https:\/\//}" "$addonBranch" "${addonLocalBranch}" "${addonRemoteTrackingBranch}" "${addonDiagnosticMessage}"

}

#set -ex
while read addon;
do
  # ignore commented addons in addons.txt
  if (echo $addon | grep -q '#'); then
    #echo "Continue commented addon !"
    continue;
  fi
  # Skip empty lines. -z checks 0-length
  strippedAddon="${addon/ /}" # strip spaces
  strippedAddon="${strippedAddon/\t/}" # strip tabs
  strippedAddon="${strippedAddon/\r/}" # strip return
  strippedAddon="${strippedAddon/\n/}" # strip newline
  if [ -z "$strippedAddon" ]; then
    #echo "Skipping empty line !"
    continue;
  fi

  processAddon `echo $addon`;
  #echo ""
done < "$curDir/addons.txt"

echo "";
echo "Work = done. Enjoy. :) ";
echo "";
