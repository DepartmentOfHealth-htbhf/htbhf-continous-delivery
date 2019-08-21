#!/bin/bash

cd ${WORKING_DIR}

git fetch
git checkout gh-pages

export TEST_RESULTS_DIR=${WORKING_DIR}/docs

# move app version files
mv *_app_versions.txt ${TEST_RESULTS_DIR}

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

CD_REPO_SLUG=${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}

# publish
git add ${WORKING_DIR}/docs
git status
git config --local user.email "dhsc-htbhf-support@equalexperts.com"
git config --local user.name "ci-build"
git commit -m "Publishing test results for ${APP_NAME} ${APP_VERSION} to ${CD_REPO_SLUG}"
git push https://${GH_WRITE_TOKEN}@github.com/${CD_REPO_SLUG}.git

git checkout master
