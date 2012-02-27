#!/bin/sh -e
# Script to create a SVN rev to Git commit relational table.
# Requires to be run under a git repo which has been created using:
# 'git svn clone -s'

git log --grep="svn-id" --pretty=full | perl -ne \
    'if (s/commit\s([0-9a-z]{40}).*/\1/sm || s/git-svn-id:\s.*@([0-9]*).*/\1/) { print "$_ "}'
