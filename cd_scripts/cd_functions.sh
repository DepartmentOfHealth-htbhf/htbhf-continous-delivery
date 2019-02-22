#!/bin/bash


check_variable_is_set(){
    if [[ -z ${!1} ]]; then
        echo "$1 must be set and non empty. ($2)"
        exit 1
    fi
}

check_exit_status(){
    if [[ ${1} != 0 ]]; then
        echo "$2 failed, exiting"
        if [ "$RUN_COMPATIBILITY_TESTS" == "true" ] || [ "$RUN_PERFORMANCE_TESTS" == "true" ]; then
            echo "(publishing test results first)"
            source ${CD_SCRIPTS_DIR}/publish_test_results.sh
        fi
        exit ${1}
    fi
}

download_deploy_scripts(){
    # download the latest release of deployment scripts and extract to ${BIN_DIR}/deployment-scripts
    echo "Downloading deployment scripts"
    mkdir -p ${BIN_DIR}
    rm -rf ${BIN_DIR}/deployment-scripts
    mkdir ${BIN_DIR}/deployment-scripts
    curl -H "Authorization: token ${GH_WRITE_TOKEN}" -s https://api.github.com/repos/DepartmentOfHealth-htbhf/htbhf-deployment-scripts/releases/latest \
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

prepare_compatibility_tests(){
    if [ "$GITHUB_REPO_SLUG" == "DepartmentOfHealth-htbhf/htbhf-applicant-web-ui" ]; then
        echo "Deploying $GITHUB_REPO_SLUG - using the version of the compatibility tests in $APP_VERSION"
        export COMPATIBILITY_TESTS_DIR=${APP_PATH}
    else
        download_compatibility_tests
    fi
}

download_compatibility_tests(){
    # download the latest release of web ui (containing the compatibility tests) and extract to ${COMPATIBILITY_TESTS_DIR} (the directory will be deleted first)
    check_variable_is_set COMPATIBILITY_TESTS_DIR
    echo "Downloading latest release of compatibility tests"
    rm -rf ${COMPATIBILITY_TESTS_DIR}
    mkdir ${COMPATIBILITY_TESTS_DIR}
    curl -H "Authorization: token ${GH_WRITE_TOKEN}" -s https://api.github.com/repos/DepartmentOfHealth-htbhf/htbhf-applicant-web-ui/releases/latest \
        | grep zipball_url \
        | cut -d'"' -f4 \
        | wget -qO compatibility-tests-tmp.zip -i -
    unzip compatibility-tests-tmp.zip
    mv -f DepartmentOfHealth-htbhf-htbhf-applicant-web-ui-*/* ${COMPATIBILITY_TESTS_DIR}
    rm -rf DepartmentOfHealth-htbhf-htbhf-applicant-web-ui-*
    rm compatibility-tests-tmp.zip
}

download_performance_tests(){
    if [[ ! -e ${PERF_TESTS_DIR}/htbhf-performance-tests-${PERF_TESTS_VERSION}.jar ]]; then
        echo "Downloading performance tests"
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
    wget -q -O manifest.jar ${MANIFEST_URL}
    # extract the manifest into the current directory
    jar -xf manifest.jar
    export APP_PATH=artefact.jar
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
    echo "    THRESHOLD_95TH_PERCENTILE_MILLIS: ${THRESHOLD_95TH_PERCENTILE_MILLIS}" >> ${manifest}
    echo "    THRESHOLD_MEAN_MILLIS: ${THRESHOLD_MEAN_MILLIS}" >> ${manifest}
}

wait_for_perf_tests_to_complete() {
    echo "Waiting for performance tests to complete"
    # follow the logs until we see 'Finished running gatling tests'
    PT_RESULT=$( (cf logs ${PERF_TEST_APP_NAME} &) | grep -q "Finished running gatling tests - result=" | cut -d= -f2 )
    echo "Performance tests complete, result=${PT_RESULT}"
    return ${PT_RESULT}
}

download_perf_test_results(){
    echo "Downloading performance test report"
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
    wait_for_perf_tests_to_complete
    PT_RESULT=$?

    download_perf_test_results

    echo "cf stop ${PERF_TEST_APP_NAME}"
    cf stop ${PERF_TEST_APP_NAME}
    echo "cf delete -f ${PERF_TEST_APP_NAME}"
    cf delete -f ${PERF_TEST_APP_NAME}

    cd ${WORKING_DIR}
    return ${PT_RESULT}
}
