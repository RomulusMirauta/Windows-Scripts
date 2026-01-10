
# THE LOGIC

## git = database; commit = record
## commit = snapshot + metadata + parent
## snapshot = a complete photograph of your entire project's current state (a pointer to every file, exactly as it existed)
## metadata = who, when, why created the commit (why = commit message)

## parent = previous commit hash
## children = current commit hash

## this creates a chain => each commit points to its parent - always backward
## first commit has no parent (is the origin point of the project's history)

## children know their parents (<=> past)
## parents do not know their children (<=> future)

## branch = instant sticky note/label (e.g. feature-login, bugfix/ui/button-overlap, preview), pointer, small text file that contains the hash of a commit; branches don't contain commits, they point at them; new commit created => pointer sliding forward, now pointing to current branch's new commit
## head = pointer to current working branch; head does not point to a commit

## merge = combining changes from two branches into one

## Git has 3 areas
### I. The Working Directory = local, on disk, where you edit files normally
### II. The Staging Area = The Index = The Waiting Room (after git add => queueing up changes you want to include in your next commit)
### III. The Repository = The Database of Commits = The Permanent History (after git commit => staging area is cleared)

## Remote/Cloud Storage (Personal/Workspace, like GitHub, GitLab, Bitbucket):
### This is where your repository lives in the cloud, accessible anywhere and usually shared with collaborators
### In Git terms, it’s called a remote repository (commonly named origin)
### You copy (push) your commits from your local repo to the remote/cloud

## hash = Commit (Unique) Identity = Content + Metadata + Parent



# Login to GitHub

git config --global credential.helper manager



# Initial repository creation

git init
## initializes a new Git repository in the current directory. It creates the .git directory (the repository metadata) and makes the folder a working tree you can start committing from

git add .
## stages (adds) ALL new and modified files from the current directory (and subdirectories) into the index so they will be included in the next commit. It respects .gitignore (ignored files are not staged)
## . = the current directory and everything under it
## does NOT stage file deletions reliably — use git add -A or git add -u to stage deletions as well

git commit -m "initial commit"
## creates a new commit containing whatever is currently staged (the index) and sets its commit message to "initial commit".

git remote add origin https://github.com/RomulusMirauta/%REPO_NAME%
## made a mistake - adding wrong origin? => git remote rm origin

git push --set-upstream origin main
## <=> git push -u origin main
## sets the upstream: links your local main branch to origin/main (the remote branch) => future pushes will go to origin/main by default
## uploads commits from your local repo to the remote/cloud repo



# Change the commit message (before pushing)

git commit --amend -m "new message"



# Stage: (add) new files, modified files, deletions - from last commit (before pushing)

git add -A
## same as: git add --all

## With an explicit pathspec (e.g. git add -A src/), it limits to that path
## With no pathspec, it will consider the whole repository

## *no need to change the last commit message?
git commit --amend --no-edit



# Stage: modifications and deletions of tracked files ONLY - from last commit (before pushing)

git add -u
## same as: git add --update

## Does NOT stage new/untracked files
## You can scope it: "git add -u src/" stages updates/deletes under src directory only



# Useful commands

git add --dry-run .
## Dry run to see what would be staged

git status; git diff --staged
## Check staged vs unstaged

git checkout -b main
git checkout -b feature-login
## Move the HEAD - to a previous commit => detached => HEADLESS (safe, history unchanged). Only HEAD moves, branches and commits stay in place
## Useful when needing to: Explore History

git reset
## Move the Branch - to a previous commit (danger level = medium-HIGH)
## Useful when needing to: Reshape local work / start from specific point/beginning

git revert
## Add a new commit - for corrective operations (nothing moves, safe)
## Useful when needing to: undo something already pushed and shared. You cannot rewrite Shared History!
## Creates a new commit that undoes changes - nothing is deleted. Safe, because History is preserved

git rebase
## Rewriting History
## Move or "replay" your branch's commits on top of (current state of) another branch => creating a linear history. It’s often used to update a feature branch, with the latest changes from main, before merging.
## WARNING! Don’t rebase shared/public branches unless you coordinate — rebase rewrites history! 
## Others may have work based on those commits. Changing them will cause merge conflicts for everyone.
## Only rebase local, unpushed commits - if needed!
## parent changes => hash changes => new commit!
## Same changes, but completely new commits
## Possible issues - on merging: duplicate changes, conflicts

git reflog
## In case of emergency - made a mistake: git reset --hard, git rebase (wrongly) => commits are gone
## Shows your Recent History - everywhere HEAD has pointed recently, every checkout, every commit, every reset
## Commits can be recovered!
## Act fast! Entries expire: 90 days for reachable commits, 30 days for unreachable (orphaned) commits

git merge --abort
# To cancel the last merge (before committing)

git branch -m new-branch-name
# Rename the branch you are currently on

git remote show origin
# Check remote 'origin' details and which branch is considered the remote default (HEAD branch)

git branch --all      
# Show all branches - local and remote



# Remove last Commit - that has not been pushed

## Moves branch only, keeps staging and working directory => Uncommit changes, but keep staged the changes from the removed commit (orphaned commits eventually get garbage collected, usually after 30/90 days)
git reset --soft HEAD~1

## Mixed *(default)*: moves branch, clears staging, keeps working directory => Uncommit changes, unstaged, but keep changes in working tree (orphaned garbage collector will delete them after 30/90 days) 
git reset --mixed HEAD~1 
## this is the *default* <=> git reset

## ***DANGER!*** Everything: Moves branch, clears staging AND working directory => Changes from the removed commit and all affected (changed) local files will be DELETED!
git reset --hard HEAD~1



# Merge Branches (merge the preview branch into the main branch)

git checkout main
## move HEAD to main branch

git pull origin main
## needed if a colleague previously pushed on main

git merge preview
## merging branches: preview into main (locally)

git push origin main
## sync changes on remote repo



# Empty repo

git init
git add .
git commit -m "emptied repo"
git remote add origin https://github.com/RomulusMirauta/%REPO_NAME%
git push



# First commit after emptied repo

git add .
git commit -m "first commit after emptied repo"
git remote add origin https://github.com/RomulusMirauta/%REPO_NAME%
git push



# Update repo

git status
git add .
git commit -m "refactored code"
git push



# Update Profile README.md

git status
git add "README.md"
git commit -m "updated README.md"
git push



# Clone a Repository (locally)

git clone https://github.com/%Username%/%ProjectName%.git



# Contributing To GitHub Projects - example

git clone https://github.com/RomulusMirauta/markdown-badges
cd markdown-badges
git remote add upstream https://github.com/Ileriayo/markdown-badges
git checkout -b adding-new-badges
## _MAKE MODS LOCALLY_
git status
git add .
git commit -m "Added badge for Hearthstone Collection"
git checkout -b added-badge-hearthstone-collection
git push origin added-badge-hearthstone-collection

## requested by the owner of the original project
git checkout -b adding-new-badges
git merge adding-new-badges
## requested by the owner of the original project

## _GitHub Project (owner) - Create Pull Request - WAIT_

## _MODS NEEDED?_
## _MAKE MODS LOCALLY_
git status
git add .
git commit -m "Updated code for Hearthstone Collection badge"
git push origin adding-new-badges
## _GitHub Project - Create Pull Request - WAIT_
