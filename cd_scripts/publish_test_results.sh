#!/bin/bash

git checkout gh-pages
rm -r -f ${WORKING_DIR}/docs/*

# move test results to docs directory
for f in ${RESULTS_DIRECTORY}/*simulation*; do
  mv ${f}/* ${WORKING_DIR}/docs/performance_results;
done

git add docs/
git config --local user.email "travis@travis-ci.org"
git config --local user.name "Travis CI"
git commit -m "Publishing test results"
git push https://${GH_WRITE_TOKEN}@github.com/${TRAVIS_REPO_SLUG}.git gh-pages