#!/bin/bash

# called by Travis CI

set -ex

#if [[ "false" != "$TRAVIS_PULL_REQUEST" ]]; then
#	echo "Not deploying pull requests."
#	exit
#fi
#
#if [[ "$TRAVIS_BRANCH" != "$DEPLOY_BRANCH" ]]; then
#	echo "Not on the '${DEPLOY_BRANCH}' branch."
#	exit
#fi

VIP_DOCS_DIR="/tmp/${TRAVIS_REPO_SLUG}/docs/"
VIP_PHPDOC_DIR="$TRAVIS_BUILD_DIR/../phpdoc"

# Get the encrypted private key from the repo settings
# This is the private pair to the "Travis GH Pages Deploy Key"
# The public key portion can be deleted here:
# https://github.com/Automattic/vip-go-mu-plugins/settings/keys
# The private key is in Travis settings here:
# https://travis-ci.org/Automattic/vip-go-mu-plugins/settings
# Turn off echo for the private key
set +x
echo -e $VIP_GITHUB_DEPLOY_KEY > /tmp/vip_deploy_key
chmod 600 /tmp/vip_deploy_key
set -x

# Ensure we use our deploy key when connecting to GitHub,
# this allows us to write (as the deploy key has write perms)
echo -e "\nHost github.com \n  IdentityFile /tmp/vip_deploy_key \n" >> ~/.ssh/config

git clone "git@github.com:${TRAVIS_REPO_SLUG}.git" ${VIP_DOCS_DIR}
cd ${VIP_DOCS_DIR}
git fetch --all
git checkout gh-pages

mkdir -p $VIP_PHPDOC_DIR
cd $VIP_PHPDOC_DIR

# Composer runs faster without Xdebug, and we don't need Xdebug any more
phpenv config-rm xdebug.ini

# Using Composer to install PHPDoc is slower than other methods, but installs
# a more up to date version.
composer require phpdocumentor/phpdocumentor
PATH="$PATH:${VIP_PHPDOC_DIR}/vendor/phpdocumentor/phpdocumentor/bin/"
echo $PATH

cd "${TRAVIS_BUILD_DIR}"

# See phpdoc.dist.xml for the majority of the configuration. You can override
# phpdoc.dist.xml in it's entirety by providing a file named phpdoc.xml.
# The command switches here appear to have no equivalent in phpdoc(.dist).xml.
phpdoc run --ignore-symlinks --no-interaction --quiet --sourcecode

cd ${VIP_DOCS_DIR}

git config user.name "Travis CI"
git config user.email "travis@travis-ci.com"
git config push.default "current"

git add -A .

set +ex
# Make a commit message for GitHub Pages which concatenates all
# the commit messages from the commit ranges that we just processed
# in this Travis run.
GIT_MSG=$( printf %"s \n\n" "Built at ${TRAVIS_REPO_SLUG}@${TRAVIS_COMMIT}" "Commits included:" "$(git log ${TRAVIS_COMMIT_RANGE})"; )
set -x
git commit -am "${GIT_MSG}"
if [ 0 != $? ]; then
	echo "Nothing to push"
else
	git branch
	git push
	echo "Pushing!"
fi

