#!/bin/bash

# if this is a pull request or branch (non-master) build, then just exit
echo "TRAVIS_PULL_REQUEST=$TRAVIS_PULL_REQUEST, TRAVIS_BRANCH=$TRAVIS_BRANCH"
if [[ "$TRAVIS_PULL_REQUEST" != "false"  || "$TRAVIS_BRANCH" != "master" ]]; then
   echo "Not deploying pull request or branch build"
   exit
fi

export WORKING_DIR=$(pwd)
export BIN_DIR=${WORKING_DIR}/bin
export PERF_TESTS_DIR=${WORKING_DIR}/performance_tests
export CD_SCRIPTS_DIR=${WORKING_DIR}/cd_scripts
export WEB_TESTS_DIR=${WORKING_DIR}/web_tests

source ${CD_SCRIPTS_DIR}/cd_functions.sh

check_variable_is_set PERF_TESTS_URL "E.g. https://dl.bintray.com/departmentofhealth-htbhf/maven/uk/gov/dhsc/htbhf/htbhf-performance-tests/"
check_variable_is_set PERF_TESTS_VERSION "The current version of the perf tests, as released to bintray"
check_variable_is_set GH_WRITE_TOKEN "A Github Personal access token with permissions to write to the repo"
check_variable_is_set TRAVIS_REPO_SLUG "E.g. DepartmentOfHealth-htbhf/htbhf-applicant-web-ui"
check_variable_is_set APP_HOST_STAGING "E.g. help-to-buy-healthy-foods-staging.london.cloudapps.digital"
check_variable_is_set APP_HOST_PRODUCTION "E.g. help-to-buy-healthy-foods.london.cloudapps.digital"

download_deploy_scripts

# SCRIPT_DIR should be set by download_deploy_scripts
check_variable_is_set SCRIPT_DIR

source ${SCRIPT_DIR}/cf_deployment_functions.sh
export PATH=$PATH:${SCRIPT_DIR}

/bin/bash ${SCRIPT_DIR}/install_cf_cli.sh;

echo "****** Deploy to staging ******"
export CF_SPACE=staging
export APP_HOST=${APP_HOST_STAGING}
deploy_application

write_app_versions

echo "Creating temporary route for integration tests"
create_random_route_name
HTBHF_APP="help-to-buy-healthy-foods-${CF_SPACE}"
cf map-route ${HTBHF_APP} ${CF_PUBLIC_DOMAIN} --hostname ${ROUTE}

prepare_web_tests

export APP_BASE_URL="https://${ROUTE}.${CF_PUBLIC_DOMAIN}"
echo "Running integration tests against ${APP_BASE_URL}"
cd ${WEB_TESTS_DIR}
npm install
npm run test:integration

RESULT=$?

echo "Removing temporary route for integration tests"
remove_route ${ROUTE} ${CF_PUBLIC_DOMAIN} ${HTBHF_APP}

npm run test:integration:report

check_exit_status $RESULT "Integration tests"

if [ "$RUN_COMPATIBILITY_TESTS" == "true" ]; then
    echo "Creating temporary route for compatibility tests"
    create_random_route_name
    HTBHF_APP="help-to-buy-healthy-foods-${CF_SPACE}"
    cf map-route ${HTBHF_APP} ${CF_PUBLIC_DOMAIN} --hostname ${ROUTE}

    echo "Running compatibility tests"
    export APP_BASE_URL="https://${ROUTE}.${CF_PUBLIC_DOMAIN}"
    cd ${WEB_TESTS_DIR}
    npm install
    npm run test:compatibility
    RESULT=$?

    if [[ ${RESULT} != 0 ]]; then
        echo "First attempt at compatibility tests failed - re-running"
        npm run test:compatibility
        RESULT=$?
    fi

    echo "Removing temporary route for compatibility tests"
    remove_route ${ROUTE} ${CF_PUBLIC_DOMAIN} ${HTBHF_APP}

    npm run test:compatibility:report
    export COMPATIBILITY_RESULTS_DIRECTORY=${WEB_TESTS_DIR}/build/reports/compatibility-report

    check_exit_status $RESULT "Browser compatibility tests"
    cd ${WORKING_DIR}

else
    echo "RUN_COMPATIBILITY_TESTS=$RUN_COMPATIBILITY_TESTS - skipping compatibility tests"
fi


if [ "$RUN_PERFORMANCE_TESTS" == "true" ]; then
    echo "Creating temporary route for performance tests"
    create_random_route_name
    HTBHF_APP="help-to-buy-healthy-foods-${CF_SPACE}"
    cf map-route ${HTBHF_APP} ${CF_PUBLIC_DOMAIN} --hostname ${ROUTE}

    echo "Running performance tests"
    export PERFORMANCE_RESULTS_DIRECTORY=`pwd`/performance_tests_results
    export APP_BASE_URL="https://${ROUTE}.${CF_PUBLIC_DOMAIN}"
    run_performance_tests
    RESULT=$?

    echo "Removing temporary route for performance tests"
    remove_route ${ROUTE} ${CF_PUBLIC_DOMAIN} ${HTBHF_APP}

    check_exit_status $RESULT "Performance tests"

else
    echo "RUN_PERFORMANCE_TESTS=$RUN_PERFORMANCE_TESTS - skipping performance tests"
fi

echo "Staging build successful";


if [ ! -z "$GITHUB_REPO_SLUG" ] ; then
    echo "Creating a release in GitHub for ${GITHUB_REPO_SLUG}"
    body="{\"tag_name\": \"v${APP_VERSION}\", \"name\": \"v${APP_VERSION}\"}"
    curl -H "Authorization: token ${GH_WRITE_TOKEN}" -H "Content-Type: application/json" -d "${body}" https://api.github.com/repos/${GITHUB_REPO_SLUG}/releases
fi


if [ "$DEPLOY_TO_PROD" == "true" ]; then
    echo "****** Deploy to production ******"
    export CF_SPACE=production
    export APP_HOST=${APP_HOST_PRODUCTION}
    deploy_application

    write_app_versions

    echo "Production build successful"
else
    echo "DEPLOY_TO_PROD='$DEPLOY_TO_PROD' - not deploying to production"
fi

echo "Publishing test results"
source ${CD_SCRIPTS_DIR}/publish_test_results.sh
