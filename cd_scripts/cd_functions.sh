#!/bin/bash


check_variable_is_set(){
    if [[ -z ${!1} ]]; then
        echo "$1 must be set and non empty. ($2)"
        exit 1
    fi
}

check_exit_status(){
    if [[ ${1} != 0 ]]; then
        echo "$2 failed, exiting (publishing test results first)"
        source ${CD_SCRIPTS_DIR}/publish_test_results.sh
        destroy_session_details_app
        remove_temporary_route "cleanup after build failure"
        exit ${1}
    fi
}

download_deploy_scripts(){
    # download the latest release of deployment scripts and extract to ${BIN_DIR}/deployment-scripts
    echo "Downloading deployment scripts"
    mkdir -p ${BIN_DIR}
    rm -rf ${BIN_DIR}/deployment-scripts
    mkdir ${BIN_DIR}/deployment-scripts
    curl -s https://api.github.com/repos/DepartmentOfHealth-htbhf/htbhf-deployment-scripts/releases/latest \
        | grep zipball_url \
        | cut -d'"' -f4 \
        | wget -qO deployment-scripts.zip -i -
    unzip deployment-scripts.zip
    mv -f DepartmentOfHealth-htbhf-htbhf-deployment-scripts-*/* ${BIN_DIR}/deployment-scripts
    rm -rf DepartmentOfHealth-htbhf-htbhf-deployment-scripts-*
    rm deployment-scripts.zip
    export SCRIPT_DIR=${BIN_DIR}/deployment-scripts
}

deploy_application(){
    cf_login
    if [ -z "$GITHUB_REPO_SLUG" ]; then
        echo "GITHUB_REPO_SLUG is empty/not set - not deploying any app";
    else
        echo "Deploying $GITHUB_REPO_SLUG ${APP_VERSION} to ${CF_SPACE}";
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
        source ${SCRIPT_DIR}/deploy.sh
        check_exit_status $? "Deployment to ${CF_SPACE}"

        cd ${WORKING_DIR}
    fi
}

prepare_web_tests(){
    if [ "$GITHUB_REPO_SLUG" == "DepartmentOfHealth-htbhf/htbhf-applicant-web-ui" ]; then
        echo "Deploying $GITHUB_REPO_SLUG - using the version of the web tests in $APP_VERSION"
        export WEB_TESTS_DIR=${APP_PATH}
    else
        download_web_tests
    fi

    set_feature_toggles
    set_web_test_versions
}

set_feature_toggles(){
  export FEATURE_TOGGLES=`cat "${WEB_TESTS_DIR}"/features.json`
}

set_web_test_versions(){
  echo "Versions of web test scripts to use:"
  cat ${WEB_TESTS_DIR}/test_versions.properties
  source ${WEB_TESTS_DIR}/test_versions.properties
}

download_web_tests(){
    # download the latest release of web ui (containing the compatibility and integration tests) and extract to ${WEB_TESTS_DIR} (the directory will be deleted first)
    check_variable_is_set WEB_TESTS_DIR
    echo "Downloading latest release of web ui for tests"
    rm -rf ${WEB_TESTS_DIR}
    mkdir ${WEB_TESTS_DIR}
    curl -s https://api.github.com/repos/DepartmentOfHealth-htbhf/htbhf-applicant-web-ui/releases/latest \
        | grep zipball_url \
        | cut -d'"' -f4 \
        | wget -qO web-tests-tmp.zip -i -
    unzip web-tests-tmp.zip
    mv -f DepartmentOfHealth-htbhf-htbhf-applicant-web-ui-*/* ${WEB_TESTS_DIR}
    rm -rf DepartmentOfHealth-htbhf-htbhf-applicant-web-ui-*
    rm web-tests-tmp.zip
}

download_performance_tests(){
    if [[ ! -e ${PERF_TESTS_DIR}/htbhf-performance-tests-${PERF_TESTS_VERSION}.jar ]]; then
        echo "Downloading performance tests version ${PERF_TESTS_VERSION}"
        mkdir -p ${PERF_TESTS_DIR}
        cd ${PERF_TESTS_DIR}
        wget "${PERF_TESTS_URL}/${PERF_TESTS_VERSION}/htbhf-performance-tests-${PERF_TESTS_VERSION}.jar" -q
        cd ${WORKING_DIR}
    fi
}

prepare_node_app_for_deploy(){
    # download and extract the archive
    mkdir -p application && cd application
    wget -q -O application.zip ${ZIP_URL} && unzip -o application.zip && rm application.zip
    # the archive should have a single folder - step into it to get the path
    cd *
    export APP_PATH=$(pwd)
    if [[ ! -e manifest.yml ]]; then
        echo "Error - cannot find manifest file in ${APP_PATH}"
        exit 1
    fi
}

prepare_java_app_for_deploy(){
    check_variable_is_set APP_URL
    check_variable_is_set MANIFEST_URL

    wget -q -O artefact.jar ${APP_URL}
    wget -O manifest.jar ${MANIFEST_URL}
    # extract the manifest into the current directory
    unzip -o manifest.jar manifest.yml
    export APP_PATH=artefact.jar
    "Running ls:"
    ls
}

write_perf_test_manifest(){
    manifest=$1
    echo "---" > ${manifest}
    echo "applications:" >> ${manifest}
    echo "- name: ${PERF_TEST_APP_NAME}" >> ${manifest}
    echo "  memory: 1G" >> ${manifest}
    echo "  buildpacks:" >> ${manifest}
    echo "    - java_buildpack" >> ${manifest}
    echo "  health-check-type: none" >> ${manifest}
    echo "  no-route: true" >> ${manifest}
    echo "  env:" >> ${manifest}
    echo "    BASE_URL: ${APP_BASE_URL}" >> ${manifest}
    echo "    PERF_TEST_START_NUMBER_OF_USERS: ${PERF_TEST_START_NUMBER_OF_USERS}" >> ${manifest}
    echo "    PERF_TEST_END_NUMBER_OF_USERS: ${PERF_TEST_END_NUMBER_OF_USERS}" >> ${manifest}
    echo "    PERF_TEST_SOAK_TEST_DURATION_MINUTES: ${PERF_TEST_SOAK_TEST_DURATION_MINUTES}" >> ${manifest}
    echo "    THRESHOLD_95TH_PERCENTILE_MILLIS: ${THRESHOLD_95TH_PERCENTILE_MILLIS}" >> ${manifest}
    echo "    THRESHOLD_MEAN_MILLIS: ${THRESHOLD_MEAN_MILLIS}" >> ${manifest}
    echo "    SESSION_DETAILS_BASE_URL: ${SESSION_DETAILS_BASE_URL}" >> ${manifest}

    echo "Performance test configuration:"
    echo "PERF_TEST_START_NUMBER_OF_USERS: ${PERF_TEST_START_NUMBER_OF_USERS}"
    echo "PERF_TEST_END_NUMBER_OF_USERS: ${PERF_TEST_END_NUMBER_OF_USERS}"
    echo "THRESHOLD_95TH_PERCENTILE_MILLIS: ${THRESHOLD_95TH_PERCENTILE_MILLIS}"
    echo "THRESHOLD_MEAN_MILLIS: ${THRESHOLD_MEAN_MILLIS}"
}

wait_for_perf_tests_to_complete() {
    echo "Waiting for performance tests to complete"
    # follow the logs until we see 'Finished running gatling tests', or we've been waiting for 9 minutes (circleci will kill the build after 10 minutes without response)
    (timeout 540 cf logs ${PERF_TEST_APP_NAME} &) | grep -q "Finished running gatling tests"
    PT_RESULT=$( cf logs ${PERF_TEST_APP_NAME} --recent | grep "Finished running gatling tests - result=" | cut -d= -f2 )
    echo "Performance tests complete, result=${PT_RESULT}"
    echo "Last 100 lines of the performance logs:"
    cf logs ${PERF_TEST_APP_NAME} --recent | tail -100
    return ${PT_RESULT}
}

download_perf_test_results(){
    echo "Downloading performance test report to ${PERFORMANCE_RESULTS_DIRECTORY}"
    GUID=$(cf app ${PERF_TEST_APP_NAME} --guid)
    SSH_CODE=$(cf ssh-code)
    sshpass -p ${SSH_CODE} scp -q -P 2222 -o StrictHostKeyChecking=no -o User=cf:${GUID}/0 ssh.london.cloud.service.gov.uk:/app/performance-test-results.zip .
    mkdir -p ${PERFORMANCE_RESULTS_DIRECTORY}
    unzip performance-test-results.zip -d ${PERFORMANCE_RESULTS_DIRECTORY}
}

run_performance_tests(){
    download_performance_tests

    cd ${PERF_TESTS_DIR}
    export PERF_TEST_APP_NAME=htbhf-performance-tests

    write_perf_test_manifest manifest.yml

    echo "cf push -f manifest.yml -p htbhf-performance-tests-${PERF_TESTS_VERSION}.jar"
    cf push -f manifest.yml -p htbhf-performance-tests-${PERF_TESTS_VERSION}.jar
    if [[ $? != 0 ]]; then
        echo "Deployment of ${PERF_TEST_APP_NAME} to ${CF_SPACE} failed. Logs from deployment:"
        cf logs  ${PERF_TEST_APP_NAME} --recent
        PT_RESULT=1
    else
        wait_for_perf_tests_to_complete
        PT_RESULT=$?

        download_perf_test_results

        echo "cf stop ${PERF_TEST_APP_NAME}"
        cf stop ${PERF_TEST_APP_NAME}
    fi

    echo "cf delete -f ${PERF_TEST_APP_NAME}"
    cf delete -f ${PERF_TEST_APP_NAME}

    cd ${WORKING_DIR}
    return ${PT_RESULT}
}

write_app_versions(){
    echo "Listing app versions deployed in ${CF_SPACE}:"

    export APP_VERSIONS_FILE="${CF_SPACE}_app_versions.txt"
    rm -f $APP_VERSIONS_FILE

    # get a list of the names of all apps in the current space
    TEMP_APP_NAMES=$(cf apps | grep '[0-9]/[0-9]' | awk '{print $1}')
    # Iterate the apps to get the version number
    for appName in $TEMP_APP_NAMES; do
        appVersion=$(cf env $appName | grep 'APP_VERSION' | awk '{print $2}')
        # add an entry to the file if we have an app version
        if [ ! -z "${appVersion}" ]; then
            echo "${appName}:   ${appVersion}" >> $APP_VERSIONS_FILE
        fi
    done

    # sort the file
    sort -o $APP_VERSIONS_FILE $APP_VERSIONS_FILE
    # echo the contents
    cat $APP_VERSIONS_FILE
}

create_temporary_route(){
    echo "Creating temporary route for ${1} (to ${HTBHF_APP})"
    create_random_route_name
    cf map-route ${HTBHF_APP} ${CF_PUBLIC_DOMAIN} --hostname ${ROUTE}

    export APP_BASE_URL="https://${ROUTE}.${CF_PUBLIC_DOMAIN}"
}

remove_temporary_route(){
    echo "Removing temporary route for ${1}"
    remove_route ${ROUTE} ${CF_PUBLIC_DOMAIN} ${HTBHF_APP}
}

deploy_session_details_app() {
    export SESSION_DETAILS_APP=htbhf-session-details-${CF_SPACE}
    SESSION_DETAILS_HOST="${ROUTE}.${CF_PUBLIC_DOMAIN}"
    echo "Deploying ${SESSION_DETAILS_APP} to ${SESSION_DETAILS_HOST}"
    cf push -f src/test/session-details-provider/session-details-manifest.yml --var session_details_app_name=${SESSION_DETAILS_APP} --var session_secret=secret_${SESSION_SECRET} --var session_details_host_name=${SESSION_DETAILS_HOST}
    RESULT=$?
    if [[ ${RESULT} != 0 ]]; then
        cf logs ${SESSION_DETAILS_APP} --recent
        echo "cf push of session-details-app failed - exiting now"
        exit 1
    fi
    export SESSION_DETAILS_BASE_URL="https://${SESSION_DETAILS_HOST}"
    echo "Session details app accessible at ${SESSION_DETAILS_BASE_URL}/session-details"
}

destroy_session_details_app(){
    cf delete -f -r ${SESSION_DETAILS_APP}
}
