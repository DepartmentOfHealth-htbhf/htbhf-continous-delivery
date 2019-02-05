#!/bin/bash

git fetch
git checkout gh-pages

export TEST_RESULTS_DIR=${WORKING_DIR}/docs

# clear compatibility test results
rm -r -f ${TEST_RESULTS_DIR}/compatibility-report

# move compatibility test results to docs directory if we ran them
if [ ! -z "${COMPATIBILITY_RESULTS_DIRECTORY}" ]; then
  mv ${COMPATIBILITY_RESULTS_DIRECTORY} ${TEST_RESULTS_DIR}
fi

# clear performance test results
export PERFORMANCE_TEST_RESULTS=${TEST_RESULTS_DIR}/performance_results
rm -r -f ${PERFORMANCE_TEST_RESULTS}
mkdir -p ${PERFORMANCE_TEST_RESULTS}

# move performance test results to docs directory if we ran them
if [ ! -z "${PERFORMANCE_RESULTS_DIRECTORY}" ]; then
  for f in ${PERFORMANCE_RESULTS_DIRECTORY}/*simulation*; do
    mv ${f}/* ${PERFORMANCE_TEST_RESULTS};
  done
fi

# publish
git add docs/
git config --local user.email "travis@travis-ci.org"
git config --local user.name "Travis CI"
git commit -m "Publishing test results"
git push https://${GH_WRITE_TOKEN}@github.com/${TRAVIS_REPO_SLUG}.git

git checkout master