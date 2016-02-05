#!/usr/bin/env bash

# git_move_filter.sh in http://github.com/wilsonmar/git-utilities
# Example: after chmod 777 git_move_filter.sh
# ./git_move_history.sh /Users/wmar/gits/wilsonmar/SampleB/folderB1 /Users/wmar/gits/wilsonmar/SampleA/folderB1 /Users/wmar/gits/wilsonmar/SampleA/folderB1.patch

# Before running this script:
# This assumes that repos have already been setup:
#    http://github.com/wilsonmar/SampleA
#    http://github.com/wilsonmar/SampleB


## My standard starter. 
# Set exit logic. Read: http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail 
IFS=$'\n\t'
# Log to syslog:
#exec 1> >(logger -s -t $(basename $0)) 2>&1
# Standard System Variables:
NOW=$(date)
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
SYSTEM=${OSTYPE//[0-9.]/}
HNAME=$(hostname)
SCRIPT="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"

clear
echo "*** SYSTEM=${SYSTEM}, HNAME=${HNAME}."
echo "*** SCRIPT=${SCRIPT}, NOW=${NOW}."
echo "*** Run from DIR=${DIR}."
git status # don't continue unless there is a clean slate.

# To use gg command in place of git (From Michael Hill):
function gg ()
{
   local _gg="$1";
   shift;
   git --git-dir="${_gg}/.git" --work-tree="${_gg}" "$@"
}

## Initialize variables just for this script:
echo "*** STEP 01: Get local tempory working folder ready to receive the clone:"
TMP='/tmp/git_move_filter' # named after name of script.
rm -Rf ${TMP}
mkdir ${TMP}
cd ${TMP}
echo "*** Now at working folder TMP=${TMP}."

echo "*** STEP 02: Clone the originating repo on your local machine:"
repoA='https://github.com/wilsonmar/SampleA' # from
branchA="master"
clone_folder='SampleA-work-repo'
folderA1='folderA1' # from git_move_setup.sh

repoB_folder="SampleB"
repoB='https://github.com/wilsonmar/SampleB' # destination
branchB="master"
dest_folder='SampleA-added' #destination
echo "*** repoA=$repoA."
echo "*** repoB=$repoB."

git clone -b ${branchA} $repoA $clone_folder # Create folder from Github
cd $clone_folder
dir=`pwd` # put results of pwd command into variable dir.
echo "*** dir=$dir"


echo "*** STEP 03: List files caz the next action promotes files in the directory up to the project root level:"
ls -al

echo "*** STEP 04: Avoid accidentally pushing changes by deleting the upstream repository definition in github:"
git remote -v
git remote rm origin
git remote -v

echo "*** After this step, the local repo must be reset again using ./git_move_setup.sh."
echo "*** STEP 05: Filter out all files except the one you want and at the same time "
git filter-branch --prune-empty --subdirectory-filter $folderA1 -- --all
#   The `--prune-empty` with `git filter-branch` brings over commits from **ONLY** the other repo which involves the directory being moved.
#   The official doc at https://git-scm.com/docs/git-filter-branch
#   describes git filter-branch as rewrite revision history what is specifically mentioned after `--subdirectory-filter`.
#   The `–-` (two dashes) separates paths from revisions.
#   An example of the response (where "folderA1" is replaced with your folder name):
# Sample response: 
#           Rewrite ce91108524893c98adae9a4db9fbeebdec2affbe (21/21)
#           Ref 'refs/heads/master' was rewritten
#           Total 16
# This should list just the files:
ls -al

echo "*** STEP 06: Move contents of file raised to root back into a destination directory:"
mkdir -p $dest_folder
# TODO: Move more than just .txt files we know:
find . -type f -exec git mv {} ${dest_folder} \;
# Some fatal: not under version control
#git mv *.txt $dest_folder # As in git mv *  SampleA-folder1 but cannot move a directory into itself.
pwd
ls -al
# git remote -v returns nothing here.

echo "*** STEP 07: Commit:"
git add .
git commit -m"Move ${folderA1} to ${dest_folder}, ${NOW}."

echo "*** STEP 08: Clone ${repoB_folder} into ${TMP}:"
cd /
cd ${TMP}
pwd
rm -rf ${repoB_folder}
git clone -b ${branchB} ${repoB} ${repoB_folder} # Create folder from Github
cd $repoB_folder

echo "*** STEP 09: Remove previously added folder in ${repoB_folder}:"
# ls ${dest_folder}
git status
git add . -A
rm -rf ${dest_folder}
#echo "*** Error out here if error handling is more strict:"
#ls ${dest_folder} # Should say "No such file or directory."

echo "*** STEP 10: Add location to pull from ${TMP}/${repoB_folder}:"
pwd
cd ${TMP}/${repoB_folder}
git remote add repoA-branch ${TMP}/${clone_folder}
git remote -v
#mkdir ${TMP}/${dest_folder}
#cd ${dest_folder}

echo "*** STEP 11: Reset --hard to remove pendings, avoid vim coming up:"
cd ${TMP}/${repoB_folder}
pwd
git reset --hard
git pull       repoA-branch master
# Response includes: Merge made by the 'recursive' strategy.
git remote rm  repoA-branch
git remote -v

echo "*** STEP 12: Commit to Github:"
pwd
git status
# Your branch is ahead of 'origin/master' by 23 commits.
git add . -A
git commit -m"Move ${repoB_folder} from ${repoA} using git_move_filter.sh ${NOW}."
git remote -v
git push

# FIXME: This is putting in github but
# it's putting extra file fileA2a.txt and fileA2b.txt when
# Only fileA1a.txt and fileA1b.txt are expected.