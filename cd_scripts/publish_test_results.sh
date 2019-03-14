#!/bin/bash

cd ${WORKING_DIR}

git fetch
git checkout gh-pages

export TEST_RESULTS_DIR=${WORKING_DIR}/docs

# move compatibility test results to docs directory if we ran them
if [ ! -z "${COMPATIBILITY_RESULTS_DIRECTORY}" ]; then
  # clear existing compatibility test results first
  rm -r -f ${TEST_RESULTS_DIR}/compatibility-report
  echo "copying compatibility test results from ${COMPATIBILITY_RESULTS_DIRECTORY} to ${TEST_RESULTS_DIR}"
  mv ${COMPATIBILITY_RESULTS_DIRECTORY} ${TEST_RESULTS_DIR}
else
  echo "no COMPATIBILITY_RESULTS_DIRECTORY found"
fi

# move performance test results to docs directory if we ran them
if [ ! -z "${PERFORMANCE_RESULTS_DIRECTORY}" ]; then
  # clear existing performance test results first
  export PERFORMANCE_TEST_RESULTS=${TEST_RESULTS_DIR}/performance_results
  rm -r -f ${PERFORMANCE_TEST_RESULTS}
  mkdir -p ${PERFORMANCE_TEST_RESULTS}
  echo "copying performance test results from ${PERFORMANCE_RESULTS_DIRECTORY} to ${PERFORMANCE_TEST_RESULTS}"
  for f in ${PERFORMANCE_RESULTS_DIRECTORY}/*simulation*; do
    mv ${f}/* ${PERFORMANCE_TEST_RESULTS};
  done
else
  echo "no PERFORMANCE_RESULTS_DIRECTORY found"
fi

# publish
git add ${WORKING_DIR}/docs
git config --local user.email "travis@travis-ci.org"
git config --local user.name "Travis CI"
git commit -m "Publishing test results"
git push https://${GH_WRITE_TOKEN}@github.com/${TRAVIS_REPO_SLUG}.git

git checkout master