#!/bin/bash

if [ "$TRAVIS_REPO_SLUG" == "mvdavid7/five-bomber" ] && [ "$TRAVIS_PULL_REQUEST" == "false" ] && [ "$TRAVIS_BRANCH" == "master" ]; then
  echo -e "Publishing to gh-pages...\n"

  cp -R build/web $HOME/five-bomber-latest

  cd $HOME
  git config --global user.email "travis@travis-ci.org"
  git config --global user.name "travis-ci"
  git clone --quiet --branch=gh-pages https://${GH_TOKEN}@${GH_REF} gh-pages > /dev/null

  cd gh-pages
  git rm -rf ./
  cp -Rf $HOME/five-bomber-latest/* ./
  git add -f .
  git commit -m "Deploying Travis build $TRAVIS_BUILD_NUMBER"
  git push -fq origin gh-pages > /dev/null

  echo -e "Published.\n"
fi
