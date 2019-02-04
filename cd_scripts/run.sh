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
export COMPATIBILITY_TESTS_DIR=${WORKING_DIR}/compatibility_tests

source ${CD_SCRIPTS_DIR}/cd_functions.sh

check_variable_is_set PERF_TESTS_URL
check_variable_is_set PERF_TESTS_VERSION
check_variable_is_set GH_WRITE_TOKEN
check_variable_is_set TRAVIS_REPO_SLUG
check_variable_is_set APP_HOST_STAGING

download_deploy_scripts

# SCRIPT_DIR should be set by download_deploy_scripts
check_variable_is_set SCRIPT_DIR

source ${SCRIPT_DIR}/cf_deployment_functions.sh
export PATH=$PATH:${SCRIPT_DIR}
export CF_SPACE=staging


if [ -z "$GITHUB_REPO_SLUG" ]; then
    echo "GITHUB_REPO_SLUG is empty/not set - not deploying any app";

else
    echo "Deploying $GITHUB_REPO_SLUG";
    check_variable_is_set APP_NAME
    check_variable_is_set APP_VERSION

    echo "Determining whether to deploy node or java application (will be node if ZIP_URL is set: '$ZIP_URL')"
    if [[ ${ZIP_URL} ]]; then
        echo "Deploying Node.js app from '${ZIP_URL}'"
        prepare_node_app_for_deploy
    else
        echo "Deploying Java app from '${APP_URL}' using manifest from '${MANIFEST_URL}'"
        prepare_java_app_for_deploy
    fi

    export SMOKE_TESTS=${CD_SCRIPTS_DIR}/deploy_smoke_test.sh
    export APP_HOST=${APP_HOST_STAGING}

    source ${SCRIPT_DIR}/deploy.sh
    check_exit_status $? "Deployment"

    cd ${WORKING_DIR}
fi


if [ "$RUN_COMPATIBILITY_TESTS" == "true" ]; then
    prepare_compatibility_tests

    echo "Creating temporary route for compatibility tests"
    create_random_route_name
    HTBHF_APP="help-to-buy-healthy-foods-${CF_SPACE}"
    cf map-route ${HTBHF_APP} ${CF_PUBLIC_DOMAIN} --hostname ${ROUTE}

    echo "Running compatibility tests"
    export APP_BASE_URL="https://${ROUTE}.${CF_PUBLIC_DOMAIN}"
    cd ${COMPATIBILITY_TESTS_DIR}
    npm install
    npm run test:compatibility
    RESULT=$?

    echo "Removing temporary route"
    remove_route ${ROUTE} ${CF_PUBLIC_DOMAIN} ${HTBHF_APP}

    npm run test:compatibility:report
    export COMPATIBILITY_RESULTS_DIRECTORY=${COMPATIBILITY_TESTS_DIR}/build/reports/compatibility-report

    check_exit_status $RESULT "Browser compatibility tests"
    cd ${WORKING_DIR}

else
    echo "RUN_COMPATIBILITY_TESTS=$RUN_COMPATIBILITY_TESTS - skipping compatibility tests"
fi


if [ "$RUN_PERFORMANCE_TESTS" == "true" ]; then
    download_performance_tests

    echo "Running performance tests"
    export PERFORMANCE_RESULTS_DIRECTORY=`pwd`/performance_tests_results
    source ${PERF_TESTS_DIR}/run_performance_tests.sh
    RESULT=$?

    check_exit_status $RESULT "Performance tests"

else
    echo "RUN_PERFORMANCE_TESTS=$RUN_PERFORMANCE_TESTS - skipping performance tests"
fi


if [ "$RUN_COMPATIBILITY_TESTS" == "true" ] || [ "$RUN_PERFORMANCE_TESTS" == "true" ]; then
    echo "Publishing test results"
    source ${CD_SCRIPTS_DIR}/publish_test_results.sh
fi


if [ -z "$GITHUB_REPO_SLUG" ]; then
    echo "Staging build successful";

else
    echo "Staging build successful - Creating a release in GitHub for ${GITHUB_REPO_SLUG}"
    body="{\"tag_name\": \"v${APP_VERSION}\", \"name\": \"v${APP_VERSION}\"}"
    curl -H "Authorization: token ${GH_WRITE_TOKEN}" -H "Content-Type: application/json" -d "${body}" https://api.github.com/repos/${GITHUB_REPO_SLUG}/releases
fi

