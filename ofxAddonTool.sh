#!/bin/bash

# ofxAddonTool is am addon dependency manager for OpenFrameworks projects.
# It works together with an addons.txt as config file.
# Place this script in your oF project's root, or any subfolder.

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

VERSION_NUMBER="0.4_alpha";

# Terminal color definitions
style_red=$(tput setaf 1)
style_green=$(tput setaf 2)
style_yellow=$(tput setaf 3)
#style_cyan=$(tput setaf 7)
style_bold=$(tput bold)
style_light=$(tput dim)
style_reset=$(tput sgr 0)

# Helper function
function showLoadMessage {
  let taskPid=$!;
  local taskMessage=$1;
  if [[ -z "$taskMessage" ]]; then
    taskMessage="Loading"; # Default message
  fi
  echo -ne " ${style_light}$taskMessage${style_reset}\r"

  while kill -0 $taskPid 2>/dev/null; do
  #while wait 0.3s $taskPid 2>/dev/null; do
    sleep 0.3
    echo -ne " ${style_light}$taskMessage.${style_reset}\r"
    sleep 0.3
    echo -ne " ${style_light}$taskMessage..${style_reset}\r"
    sleep 0.3
    echo -ne " ${style_light}$taskMessage...${style_reset}\r"
    sleep 0.3
    echo -ne "\r\033[K"
    echo -ne " ${style_light}$taskMessage${style_reset}\r"
  done

  # forward exit code of process
  wait $taskPid # retrieves exit code into $?
  #echo "Done with code=$?     ";
  #return $?;
};

# Function to filter lines in addons.txt
function filterAddonLine {
  # parse argument
  local addonLine=$1;

  # ignore commented lines
  if [[ ! -z `echo "$addonLine" | grep '#'` ]]; then
    ignoringName=`echo ${addonLine/\#/} | grep "^ofx" | cut -f1 -d ' '`;
    if [[ ! -z "$ignoringName" && "$VERBOSE" -eq 1 ]] ; then
      echo "Verbose: Ignoring commented addon : $ignoringName"
    fi
    # Ignore addon or empty line
    return 255;
  fi

  # Skip empty lines.
  strippedAddon="${addonLine/ /}" # strip spaces
  strippedAddon="${strippedAddon/\t/}" # strip tabs
  strippedAddon="${strippedAddon/\r/}" # strip return
  strippedAddon="${strippedAddon/\n/}" # strip newline

  if [ -z "$strippedAddon" ]; then
    #echo "Skipping empty line !"
    #continue;
    return 255;
  fi

  #echo "$addonLine";
  return 0; # success indicator
}

# Parse parameters / options
USER_ACTION="";
INTERACTIVE=1;
SHOW_INTRO=1;
VERBOSE=0;
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
  elif [ "$arg" = "--verbose" ]; then
    VERBOSE=1;
  fi
done

# No options ? Ask user what to do
if [[ "$INTERACTIVE" -eq 1 && -z "$USER_ACTION" ]]; then
  echo   "Which action would you like to perform ? (please type a number)";
  echo   "             1. Check addon status. (default)";
  echo   "             2. Install addon dependencies.";
  echo   "             3. Update addon dependencies, or install uninstalled addons.";
  echo   "             4. Syncronize addons.txt with addons.make, making a backup if needed.";
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
  if [[ $(figlet "." 2> /dev/null ) && $? -eq 0 ]]; then
    # Figlet is installed
    figlet -w "$(tput cols)" -f big "ofxAddonTool"; # -t doesn't work on OSX. Using -w instead
  elif [[ $(toilet "." 2> /dev/null ) && $? -eq 0 ]]; then
    # Toilet is installed
    toilet -t -f big "ofxAddonTool";
  else
    # No ascii art tool is installed
    echo "        __                   _     _          _______          _ ";
    echo "       / _|         /\      | |   | |        |__   __|        | |";
    echo "  ___ | |___  __   /  \   __| | __| | ___  _ __ | | ___   ___ | |";
    echo " / _ \|  _\ \/ /  / /\ \ / _\` |/ _\` |/ _ \| '_ \| |/ _ \ / _ \| |";
    echo "| (_) | |  >  <  / ____ \ (_| | (_| | (_) | | | | | (_) | (_) | |";
    echo " \___/|_| /_/\_\/_/    \_\__,_|\__,_|\___/|_| |_|_|\___/ \___/|_|";
    echo "                                                                 ";
  fi
  
  echo "An utility for managing OpenFrameworks addon dependencies for a given project."
  echo "Version ${VERSION_NUMBER}.";
  echo "";
  echo "Usage: ofxAddonTool.sh [--yes] [--no-intro] [--verbose] --ACTION";
  echo "";
  echo "--ACTION      Action to perform :";
  echo "     --check    Shows the current stat of your OpenFrameworks' addon folder.";
  echo "     --install  Installs the required addons. (ignores if already installed)";
  echo "     --update   Tries to pull remote changes, if any are available. (only if your local branch is clean)";
  echo "                  Any missing addons will also be installed.";
  echo "     --sync     Synchronizes with addons.make using the config from addons.txt (with automatic backup creation).";
  echo "     --help     Shows the current status of your OpenFrameworks addon folder.";
  echo "";
  echo "Optional arguments :";
  echo "     --yes      Disable user interactions (for scripting usage).";
  echo "     --no-intro Don't show the intro banner.";
  echo "     --verbose  Show extra debug information.";
  echo "";
  exit 0;
fi # Endif HELP

# Get project information
curDir=`pwd`; # ofxAddonTool dir
let dirSearchLimit=3;
dirSearchPath="";
if [ `basename "$curDir"` = "ofxAddonTool" ]; then
  # project is at least 1 directory lower
  dirSearchPath="../";
fi
# Search for project path
while [ "$dirSearchLimit" -gt 0 ]; do
  # Detects a project by going down to the OF folder then looking for an addons folder
  if [ -d "${curDir}/${dirSearchPath}../../../addons" ]; then
    projectDir=$(realpath "${curDir}/${dirSearchPath}");
    #echo "Found OF/addons ! (`realpath ${projectDir}`)";
    break;
  else
    #echo "Ignoring=`basename $(realpath ${curDir}/${dirSearchPath})`";
    dirSearchPath+="../";
  fi
  # decrement
  dirSearchLimit=$[$dirSearchLimit-1];
done

# Unable to find the project root ?
if [[ -z "$projectDir" || ! -d "$projectDir" ]]; then
  echo "${style_red}ERROR : the main OF project folder was not found. Please make sure this script is located within your OF project folder.${style_reset}";
  exit 1;
fi
#projectDir=$(git rev-parse --show-toplevel); # use git to find project folder[drawback: needs to have git enabled]
#projectDir="";

repoDiagnosticMessage="";
let projectRemoteUnavailable=0;
#repoName= basename `git rev-parse --show-toplevel`;
repoName=$( basename "$projectDir" );

# Check if we have a git repo
if [[ ! -d "$projectDir/.git" ]]; then
  repoDiagnosticMessage+="${style_yellow}Warning: $repoName is not a git repository. Not checking for updates.${style_reset} ";
else
  # Check for updates
  cd "$projectDir";
  git fetch --quiet 2> /dev/null; # Hides output as --quiet doesn't silence git fatal errors such as no internet.
  let projectRemoteUnavailable=$?; # keep this line directly after to git fetch
  
  # No internet connection ?
  if [ "$projectRemoteUnavailable" -gt 0 ]; then
    # Check if git works, otherwise we probably have a network error
    if [[ ! `git status --porcelain 2> /dev/null` ]]; then
      repoDiagnosticMessage+="${style_red}Error: This local git repo might be broken.${style_reset} ";
    else
      repoDiagnosticMessage+="${style_yellow}Warning: Could not fetch updates. (probably no network)${style_reset} ";
    fi
  fi

  # Check for any modified project files
  if [[ ! -z `git status --porcelain 2> /dev/null` ]]; then
    # On update
    if [ "$USER_ACTION" = "update" ]; then
      repoDiagnosticMessage+="${style_red}Your branch has local changes, not updating to prevent conflicts. Clean the repo and try again.${style_reset} ";
    # On check
    else
      repoDiagnosticMessage+="${style_yellow}Your branch has local changes.${style_reset} ";
    fi
  fi

  # Check if new commits are available
  if [[ ! -z `git log ..@{u} 2> /dev/null` ]]; then
    # Updating Project
    if [ "$USER_ACTION" = "update" ]; then
      git pull --no-commit 2> /dev/null & showLoadMessage "Updating $addonName";

      # Error updating ?
      if [ "$?" -gt 0 ]; then
        repoDiagnosticMessage+="${style_red}Error updating.${style_reset} ";
      # Update successfull
      else
        repoDiagnosticMessage+="${style_green}Update successful !${style_reset} ";
      fi
    # Regular check
    else
      repoDiagnosticMessage+="${style_yellow}New comits are available.${style_reset} ";
    fi

  fi
fi # Main repo git checks

# Locate the addons folder
cd "$projectDir/../../../addons" >> /dev/null 2>&1 ; #silenced
#cd ../../../addons >> /dev/null 2>&1 ; #silenced
# Addon folder doesn't exist ?
if [[ $? -gt 0 ]]; then
  echo "${style_red}ERROR : the addons folder was not found.${style_reset}"
  exit 1;
fi
addonsDir=`pwd`;

# Enter project dir
cd "$projectDir";

# Show intro banner
if [ "$SHOW_INTRO" -eq 1 ]; then
  # Say hello
  echo ""
  echo "Hello, this script will scan your addons folder and check if all the necessary addons are correctly installed."
  echo "If some fields are marked yellow/red, they might need manual attention."
  echo "Note: this script is in alpha phase ($VERSION_NUMBER), feedback is appreciated."
  echo ""
  
  # Print some repository information
  if [[ $(figlet "." 2> /dev/null ) && $? -eq 0 ]]; then
    # Figlet is installed
    figlet -w "$(tput cols)" -f big " $repoName";
  elif [[ $(toilet "." 2> /dev/null ) && $? -eq 0 ]]; then
    # Toilet is installed
    toilet -f basic "$repoName";
  else
    # No ascii art tool is installed
    echo "OF Project : $repoName";
  fi
  echo   "Path       : $projectDir";
  if [[ ! -z "$repoDiagnosticMessage" ]]; then
    echo "Diagnostic : $repoDiagnosticMessage";
  else
    echo "Diagnostic : ${style_green}The base repo is clean.${style_reset}";
  fi
  echo "";
  echo "Addons configuration file : $curDir/addons.txt";
  let numInstalledAddons=$(ls -l $addonsDir | grep -v ^ofx | wc -l | xargs); # xargs strips spaces
  echo "Detected addons directory : $addonsDir ($numInstalledAddons installed addons)";
  echo "";
  #echo "Working from $repoName";
fi # end show intro banner

# Set default action
if [[ -z "$USER_ACTION" ]]; then
  USER_ACTION="check";
  if [[ "$VERBOSE" -eq 1 ]] ; then
    echo "${style_yellow}Verbose : Unrecognized script action. Continueing with default behaviour \"${USER_ACTION}\". [Warning]${style_reset}";
    echo "";
  fi
else
  if [[ "$VERBOSE" -eq 1 ]] ; then
    echo "Verbose: Starting addons action: $USER_ACTION";
    echo "";
  fi
fi

# Sync with addons.make ?
if [ "$USER_ACTION" = "sync" ]; then
  
  # Does addons.txt exist ?
  if [ ! -f "${curDir}/addons.txt" ]; then
    echo "${style_red}Error: ${curDir}/addons.txt doesn't exist, cannot sync !${style_reset}";
    exit 128;
  fi

  # Check for an existing addons.make
  if [ -f "${projectDir}/addons.make" ]; then

    # Check if it was created by ofxAddonTool
    #grep -n . "${projectDir}/addons.make" | grep "^1:.*ofxAddonTool";
    if [[ -z `grep -n . "${projectDir}/addons.make" | grep "^1:.*ofxAddonTool"` ]]; then # error with too many arguments
      if [[ "$VERBOSE" -eq 1 ]] ; then
        echo "Verbose: Existing addons.make detected. Making a backup of ${repoName}/addons.make.";
      fi

      # Check filename for addons_backup.make
      backupName=$(date +"addons_backup-%Y%m%d.make");
      let incr=1;
      while [ -f "${projectDir}/${backupName}" ]; do
        backupName=$(date +"addons_backup-%Y%m%d-$incr.make");
        incr=$[$incr + 1];
      done

      if [[ "$VERBOSE" -eq 1 ]] ; then
        echo "Verbose: Name of the backup : ${repoName}/${backupName}.";
      fi

      # Make a backup
      cp "${projectDir}/addons.make" "${projectDir}/${backupName}";
      # Did it fail ?
      if [ $? -gt 0 ]; then
        echo "${style_red}Error backing up ${repoName}/addons.make. Not continueing.${style_reset}";
        exit 128;
      # Success
      else
        # Append 1 info line saying it was duplicated by ofxAddonTool
        echo -e "# Automatic backup created by ofxAddonTool prior to overwriting addon.make on $(date +"%d-%m-%Y").\n$(cat ${projectDir}/${backupName})" > "${projectDir}/${backupName}";
        
        # Notify success
        echo "${style_green}A backup of your previous addons.make was created at ${repoName}/${backupName}.${style_reset}";
      fi

    # File was produced by ofxAddonTool
    else
      if [[ "$VERBOSE" -eq 1 ]] ; then
        echo "Verbose: addons.make detected and made by ofxAddonTool. Proceeding without making a backup.";
      fi
    fi

  # No addons.make, directly create it !
  else
    if [[ "$VERBOSE" -eq 1 ]] ; then
      echo "Verbose: ${repoName}/addons.make doesn't exist yet. Directly creating it.";
    fi
    # Continue below
  fi

  # From this point there's either a backup of addons.make or no need to back it up.
  addonsMakeFile=;
  if [[ "$VERBOSE" -eq 1 ]] ; then
    echo "Verbose: Detected target location: ${projectDir}/addons.make.";
  fi

  # Compose new addons.make
  addonsDotMakeContent="# Generated by ofxAddonTool on $(date +"%d-%m-%Y").\n";  # First line of addons.make must hold "ofxAddonTool", to detect if it was self-made or not.
  addonsDotMakeContent+="# This file reflects the more detailed addon configuration in .${curDir/$projectDir/}/addons.txt.\n"; # Prints the relative path
  addonsDotMakeContent+="# You can use .${curDir/$projectDir/}/ofxAddonTool.sh to re-sync the required addons, or to check that you are tracking the correct remote branch.\n";

  # Loop addons.txt
  while read addon; do
    filterAddonLine "$addon";
    if [ $? -eq 0 ]; then
      #local addonName=$(echo $addon | cut -f1 -d' ')
      addonsDotMakeContent+=$(echo $addon | cut -f1 -d' ');
      addonsDotMakeContent+="\n";
    fi
  done < "$curDir/addons.txt";

  # Write addons.make
  echo -e "${addonsDotMakeContent}" > "${projectDir}/addons.make";

  # Failed writing to file ?
  if [ $? -gt 0 ]; then
    echo "${style_red}Error: Failed writing to addons.make...${style_reset}";
  else
    echo "${style_green}Syncing successfull ! Addons were written to ${repoName}/addons.make.${style_reset}";
  fi
  exit 0;
fi
# End SYNC action


# Table formatting
# Column widths are set proportionally to the available terminal width
let availableWidth=`tput cols`; # in characters (not pixels)
let availableWidth=$availableWidth-5; # removes 5 column separators
# Values scale : 0=0% width, 1.0 is 100% width
# Rule : nb_cols*col_width + nb_cols2*col2_width + ... = 1.0
# BC method
#let COL_TINY=$(echo "($availableWidth * 0.04) / 1");
#let COL_SMALL=$(echo "scale=0; ($availableWidth * 0.10) / 1" | bc );
#let COL_MEDIUM=$(echo "scale=0; ($availableWidth * 0.14) / 1" | bc );
#let COL_LARGE=$(echo "scale=0; ($availableWidth * 0.22) / 1" | bc );
# AWK method
#let COL_TINY=$(awk "BEGIN {print int(($availableWidth * 0.04) / 1)}");
#let COL_SMALL=$(awk "BEGIN {print int(($availableWidth * 0.10) / 1)}");
#let COL_MEDIUM=$(awk "BEGIN {print int(($availableWidth * 0.14) / 1)}");
#let COL_LARGE=$(awk "BEGIN {print int(($availableWidth * 0.22) / 1)}");
# POSIX method
let COL_TINY=$(echo "$(($availableWidth * 4/100))");
let COL_SMALL=$(echo "$(($availableWidth * 10/100))");
let COL_MEDIUM=$(echo "$(($availableWidth * 14/100))");
let COL_LARGE=$(echo "$(($availableWidth * 22/100))");

PRINTF_TABLE_LINE="%-${COL_MEDIUM}.${COL_MEDIUM}s | %-${COL_LARGE}.${COL_LARGE}s | %-${COL_SMALL}.${COL_SMALL}s | %-${COL_SMALL}.${COL_SMALL}s | %-${COL_MEDIUM}.${COL_MEDIUM}s | %-${COL_LARGE}.${COL_LARGE}s \n";

# Table header
printf "$PRINTF_TABLE_LINE" "- - - - - - - - - - - - - - - - - - - - " "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - " "- - - - - - - - - - - - - - - - " "- - - - - - - - - - - - - - - - " "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - " "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - "
#printf "%-30s | %-50s | %-16s | %-16s | %-16s | %-16s | %-16s \n" "Addon" "Required Repo" "Needed Branch" "Exists" "Remote URL" "Local Branch" "Local Changes"
printf "$PRINTF_TABLE_LINE" "Addon" "Required Repo" "Needed Branch" "Local Branch" "Tracking target" "Diagnostic"
printf "$PRINTF_TABLE_LINE" "- - - - - - - - - - - - - - - - - - - - " "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - " "- - - - - - - - - - - - - - - - " "- - - - - - - - - - - - - - - - " "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - " "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - "

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
  local addonBranchIsSameCol=$style_reset
  local addonDiagnosticMessage=""; # Only one to include color information (not stripped).

  # Install ?
  if [[ "$USER_ACTION" == "install" || "$USER_ACTION" == "update" ]]; then
    # Already installed ?
    if [ -d "$addonsDir/$addonName" ]; then
      if [ "$USER_ACTION" = "install" ]; then
        addonDiagnosticMessage+="${style_green}Already installed.${style_reset} ";
      fi
      if [[ "$VERBOSE" -eq 1 ]] ; then
        echo "${style_green}Verbose: Already installed $addonName, not installing.${style_reset}";
      fi
    # Please install !
    else
      # Show debug info
      if [[ "$VERBOSE" -eq 1 ]] ; then
        echo "${style_yellow}Verbose: Installing addon $addonName from $addonUrl @ $addonBranch...${style_reset}";
      fi

      # Install
      cd $addonsDir;
      git clone -b $addonBranch $addonUrl $addonName 2> /dev/null & showLoadMessage "Installing $addonName";
      let addonWasInstalled=$?;

      # Install failed ?
      if [ "$addonWasInstalled" -gt 0 ]; then
        addonDiagnosticMessage+="${style_red}Failed to install.${style_reset} ";
        if [[ "$VERBOSE" -eq 1 ]] ; then
          echo " ${style_red}Failed! (error $addonWasInstalled)${style_reset}";
        fi
        # Remember the fail (todo)
      # Install was successful
      else
        addonDiagnosticMessage+="${style_green}Successfully installed.${style_reset} ";
        if [[ "$VERBOSE" -eq 1 ]] ; then
          echo " ${style_green}Verbose: Installed $addonName from $addonUrl @ $addonBranch.${style_reset}";
        fi
      fi
      
    fi
  fi

  # check if addon directory exists
  if [ -d "$addonsDir/$addonName" ]; then
    local addonExists='yes';
    local addonExistsCol=$style_green;

    # Enter addon directory
    cd $addonsDir/$addonName

    # Check for a detached head / tracking repo
    git symbolic-ref --quiet --short HEAD >> /dev/null 2> /dev/null; # quiet command, we'll use the exit code via $?
    #dummyvar=(git symbolic-ref --quiet --short no_branch_like_this); # Debug, uncomment to send exit code 1 to $?
    let addonHasDetachedHead=$? # keeps exit status of previous command. (keep this line after the previous one)
    #addonDetachedHead=$(git rev-parse --abbrev-ref HEAD) #ex: master, if tracking. Hash otherwise.

    # warn for detached head ? (override other info for GUI only)
    if [ "$addonHasDetachedHead" -gt 0 ]; then
      local addonLocalBranch="Detached!";
      local addonBranchIsSameCol=$style_red;
      
      local addonRemoteTrackingBranch="Detached head";
      local addonRemoteIsSameCol=$style_yellow;

      local addonDiagnosticMessage+="${style_yellow}This local branch is not tracking any remote branch.${style_reset} ";
    # No detached head
    else
      # Parse local information
      local addonLocalBranch=`git name-rev --name-only HEAD 2> /dev/null` # ex: master (local branch name)
      local addonTrackingRemote=`git config branch.$addonLocalBranch.remote` # ex: origin (remote's local name)
      #local addonRemoteUrl=$(git config remote.$addonTrackingRemote.url) # ex: https://github.com/armadillu/ofxTimeMeasurements
      local addonRemoteUrl=$(git remote get-url $addonTrackingRemote 2> /dev/null) # alternative for the above line
      #local addonRemoteTrackingBranch=$(git rev-parse --symbolic-full-name --abbrev-ref $addonTrackingRemote) # ex: origin/master # Note: I got some unexpected values for some repos. Better not use.
      local addonRemoteTrackingBranch=$(git rev-parse --symbolic-full-name --abbrev-ref $addonLocalBranch@{upstream}) # ex: origin/master (long version)
      #local addonRemoteTrackingBranch=$(git symbolic-ref --quiet --short HEAD) # ex: master (short version)
      
      #addonRemoteTrackingBranch=`git config branch.$addonLocalBranch.merge` #ex : refs/heads/master
      #addonRemoteTrackingBranch=`git symbolic-ref -q HEAD` #ex : refs/heads/master, exit code indicates tracking status.

      #echo "Current branch remote.name = $(git rev-parse --abbrev-ref HEAD)" # ex: master
      #echo "Entering ${mosaic_addons[$i]} @ $(git status -b -s)";
      #TRACKING_BRANCH=`git config branch.$LOCAL_BRANCH.merge` # ex: refs/heads/master

      # Check if remote URL is the same
      if [[ "$addonRemoteUrl" =~ ${addonUrl//https?\:\/\//} ]]; then
        #addonRemoteIsSame='ok'
        #addonRemoteIsSameCol=$style_green

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

          # Shows a temporary line while installing
          #echo -en "Fetching $addonName...\r";

          # Sync with remote(s), updates references
          # maybe use this instead ? : git remote update
          git fetch --quiet > /dev/null 2>&1 & showLoadMessage "Fetching $addonName" # Hides output as --quiet doesn't silence git fatal errors such as no internet.

          # Check for network errors
          let addonRemoteUnavailable=$? # keep this line directly after to git fetch

          # Check for available updates (quick method)
          lastLocalCommit=`git show --no-notes --format=format:"%H" "$addonBranch" | head -n 1`;
          lastRemoteCommit=`git show --no-notes --format=format:"%H" "$addonTrackingRemote/$addonBranch" | head -n 1`;
          let addonUpdatesAvailable=0;
          if [[ "$lastLocalCommit" != "$lastRemoteCommit" ]]; then # todo = replace this with git log, see poject method
            let addonUpdatesAvailable=1;
          fi

          # Check for diffs with remote, allowing untracked files. Don't update conflictable repos.
            #if [[ `git diff --cached --name-only $addonLocalBranch $addonTrackingRemote/$addonBranch` ]]; then # --cached includes uncomited changes
          let addonHasLocalChanges=0;
          if [[ ! -z `git status "--untracked-files=no" "--porcelain"` ]]; then
            let addonHasLocalChanges=1;
          fi

          # Perform an update ?
          if [ "$USER_ACTION" = "update" ]; then
            # Updates are available
            if [ "$addonUpdatesAvailable" -gt 0 ]; then
              # Repo is dirty ?
              if [ "$addonHasLocalChanges" -gt 0 ]; then
                addonDiagnosticMessage+="${style_red}Updates available, but the working directory is not clean. Not updating to prevent conflicts.${style_reset} ";
              # We got a clean working repo
              else

                # Update
                git pull --no-commit 1> /dev/null 2> /dev/null & showLoadMessage "Updating $addonName";

                # Error updating ?
                if [ "$?" -gt 0 ]; then
                  addonDiagnosticMessage+="${style_red}Error updating.${style_reset} ";
                # Update successfull
                else
                  addonDiagnosticMessage+="${style_green}Update successful !${style_reset} ";
                fi
              fi
            # No updates available
            else
              # Notify
              if [ "$addonHasLocalChanges" -gt 0 ]; then
                addonDiagnosticMessage+="${style_yellow}Repo up-to-date but contains local changes.${style_reset} ";
              else
                addonDiagnosticMessage+="${style_green}Already up-to-date.${style_reset} ";
              fi
            fi
          # Check or install mode
          else
            if [ "$addonHasLocalChanges" -gt 0 ]; then
              addonDiagnosticMessage+="${style_yellow}This repo has uncomited local changes.${style_reset} ";
            fi
            # Updates are available
            if [ "$addonUpdatesAvailable" -gt 0 ]; then
              addonDiagnosticMessage+="${style_yellow}New commits are available, please pull this repo.${style_reset} ";
              addonBranchIsSameCol=$style_yellow;
            fi
            #   # Check for untracked files
            #   if [[ ! -z `git status "--untracked-files=normal" "--porcelain"` ]]; then
            #     addonDiagnosticMessage+="${style_green}This repo has additional untracked files.${style_reset} "
            #   fi

            # In verbose mode, show OK diagnostic
            if [[ "$VERBOSE" -eq 1 && -z "$addonDiagnosticMessage" ]]; then
              addonDiagnosticMessage+="${style_green}Clean and up-to-date.${style_reset} ";
            fi
          fi

          # Remote unreachable (still use offline cached data for check)
          if [ "$addonRemoteUnavailable" -gt 0 ]; then
            addonDiagnosticMessage+="${style_yellow}The remote is unreachable.${style_reset} ";
          fi

        # Incorrect tracking branch
        else
          #echo "Mismatch : $addonLocalBranch is not $addonBranch"
          #echo "$addonTrackingRemote/$addonBranch VS $addonRemoteTrackingBranch"
          addonRemoteIsSameCol=$style_red
          addonDiagnosticMessage+="${style_red}Your local branch tracks a different branch.${style_reset} ";
        fi

      # Uncorrect remote url
      else
        addonDiagnosticMessage+="${style_red}Your local branch tracks a different repo/url.${style_reset} "
        addonRemoteIsSameCol=$style_red
        addonBranchIsSameCol=$style_yellow
      fi
    fi

  # Directory not found
  else
    addonDiagnosticMessage+="${style_red}This addon is not installed.${style_reset} ";
    addonBranchIsSameCol=$style_red;
    addonLocalBranch="-not installed-";
  fi

  # output table line with info
    #printf "%-20s | %-40s | %-16s | ${addonBranchIsSameCol}%-16s${style_reset} | ${addonRemoteIsSameCol}%-16s${style_reset} | ${addonDiagnosticMessageCol}%-16s${style_reset} " "${addonName:0:16}" "${addonUrl/https:\/\//}" "$addonBranch" "$addonLocalBranch" "$addonRemoteTrackingBranch" "$addonDiagnosticMessage"
  local PRINTF_TABLE_LINE_COLORED="%-${COL_MEDIUM}.${COL_MEDIUM}s | %-${COL_LARGE}.${COL_LARGE}s | %-${COL_SMALL}.${COL_SMALL}s | ${addonBranchIsSameCol}%-${COL_SMALL}.${COL_SMALL}s${style_reset} | ${addonRemoteIsSameCol}%-${COL_MEDIUM}.${COL_MEDIUM}s${style_reset} | %s${style_reset}\n";
  printf "$PRINTF_TABLE_LINE_COLORED"  "${addonName}" "${addonUrl/https:\/\//}" "$addonBranch" "${addonLocalBranch}" "${addonRemoteTrackingBranch}" "${addonDiagnosticMessage}";

}

#set -ex
while read addon; do
  filterAddonLine "$addon";
  if [ $? -eq 0 ]; then
    processAddon "$addon";
  fi
done < "$curDir/addons.txt"

echo "";
echo "Work = done. Enjoy. :) ";
echo "";
