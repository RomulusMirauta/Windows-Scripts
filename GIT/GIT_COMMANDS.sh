
# Login to GitHub

git config --global credential.helper manager



# Initial repository creation

git init
git add .
git commit -m "first commit"
git remote add origin https://github.com/RomulusMirauta/%REPO_NAME%
git push --set-upstream origin main



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
git commit -m "multiple updates"
git push



# Update Profile README.md

git status
git add .
git commit -m "updated README.md"
git push



# Clone a Repository

git clone https://github.com/%Username%/%ProjectName%.git



#Contributing To GitHub Projects - example

git clone https://github.com/RomulusMirauta/markdown-badges
cd markdown-badges
git remote add upstream https://github.com/Ileriayo/markdown-badges
git checkout -b adding-new-badges
_MAKE MODS LOCALLY_
git status
git add .
git commit -m "Added badge for Hearthstone Collection"
--git push origin added-badge-hearthstone-collection
git push origin adding-new-badges
_GitHub Project - Create Pull Request - WAIT_

_MODS NEEDED?_
_MAKE MODS LOCALLY_
git status
git add .
git commit -m "Updated code for Hearthstone Collection badge"
git push origin adding-new-badges
_GitHub Project - Create Pull Request - WAIT_
