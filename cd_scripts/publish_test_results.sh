#!/bin/bash

export PERFORMANCE_TEST_RESULTS=${WORKING_DIR}/docs/performance_results

git fetch
git checkout gh-pages
rm -r -f ${PERFORMANCE_TEST_RESULTS}
mkdir -p ${PERFORMANCE_TEST_RESULTS}

# move test results to docs directory
for f in ${RESULTS_DIRECTORY}/*simulation*; do
  mv ${f}/* ${PERFORMANCE_TEST_RESULTS};
done

git add docs/
git config --local user.email "travis@travis-ci.org"
git config --local user.name "Travis CI"
git commit -m "Publishing test results"
git push https://${GH_WRITE_TOKEN}@github.com/${TRAVIS_REPO_SLUG}.git

git checkout master