#!/bin/bash

# if this is not a triggered api build, then exit
echo "CD_BUILD=$CD_BUILD"
if [[ "$CD_BUILD" != "true" ]]; then
   echo "Not running cd build."
   exit
fi

export WORKING_DIR=$(pwd)
export BIN_DIR=${WORKING_DIR}/bin
export PERF_TESTS_DIR=${WORKING_DIR}/performance_tests
export CD_SCRIPTS_DIR=${WORKING_DIR}/cd_scripts
export WEB_TESTS_DIR=${WORKING_DIR}/web_tests

source ${CD_SCRIPTS_DIR}/cd_functions.sh

check_variable_is_set PERF_TESTS_URL "E.g. https://dl.bintray.com/departmentofhealth-htbhf/maven/uk/gov/dhsc/htbhf/htbhf-performance-tests/"
check_variable_is_set GH_WRITE_TOKEN "A Github Personal access token with permissions to write to the repo"
check_variable_is_set CIRCLECI_REPO_SLUG "E.g. DepartmentOfHealth-htbhf/htbhf-applicant-web-ui"

download_deploy_scripts

# SCRIPT_DIR should be set by download_deploy_scripts
check_variable_is_set SCRIPT_DIR

source ${SCRIPT_DIR}/cf_deployment_functions.sh
export PATH=$PATH:${SCRIPT_DIR}

/bin/bash ${SCRIPT_DIR}/install_cf_cli.sh;

echo "****** Deploy to staging ******"
export CF_SPACE=staging
export HTBHF_APP="apply-for-healthy-start-${CF_SPACE}"

deploy_application

write_app_versions

prepare_web_tests
cd ${WEB_TESTS_DIR}
npm install

create_temporary_route "staging tests"

deploy_session_details_app

echo "Running integration tests against ${APP_BASE_URL}"
npm run test:integration

RESULT=$?

check_exit_status $RESULT "Integration tests"

if [ "$RUN_COMPATIBILITY_TESTS" == "true" ]; then

    echo "Running compatibility tests against ${APP_BASE_URL}"
    npm run test:compatibility
    RESULT=$?

    npm run test:compatibility:report
    export COMPATIBILITY_RESULTS_DIRECTORY=${WEB_TESTS_DIR}/build/reports/compatibility-report

    check_exit_status $RESULT "Browser compatibility tests"

else
    echo "RUN_COMPATIBILITY_TESTS=$RUN_COMPATIBILITY_TESTS - skipping compatibility tests"
fi

cd ${WORKING_DIR}


if [ "$RUN_PERFORMANCE_TESTS" == "true" ]; then

    echo "Running performance tests"
    export PERFORMANCE_RESULTS_DIRECTORY=`pwd`/performance_tests_results
    run_performance_tests
    RESULT=$?

    check_exit_status $RESULT "Performance tests"

else
    echo "RUN_PERFORMANCE_TESTS=$RUN_PERFORMANCE_TESTS - skipping performance tests"
fi

destroy_session_details_app

remove_temporary_route "staging tests"

echo "Staging build successful";


if [ ! -z "$GITHUB_REPO_SLUG" ] ; then
    echo "Creating a release in GitHub for ${GITHUB_REPO_SLUG} version ${APP_VERSION}"
    body="{\"tag_name\": \"v${APP_VERSION}\", \"name\": \"v${APP_VERSION}\"}"
    curl -H "Authorization: token ${GH_WRITE_TOKEN}" -H "Content-Type: application/json" -d "${body}" https://api.github.com/repos/${GITHUB_REPO_SLUG}/releases
fi


if [ "$DEPLOY_TO_PROD" == "true" ]; then
    echo "****** Deploy to production ******"
    export CF_SPACE=production
    deploy_application

    write_app_versions

    echo "Production build successful"
else
    echo "DEPLOY_TO_PROD='$DEPLOY_TO_PROD' - not deploying to production"
fi

echo "Publishing test results"
source ${CD_SCRIPTS_DIR}/publish_test_results.sh
