#!/bin/bash


check_variable_is_set(){
    if [[ -z ${!1} ]]; then
        echo "$1 must be set and non empty"
        exit 1
    fi
}

check_exit_status(){
    if [[ ${1} != 0 ]]; then
        echo "$2 failed, exiting"
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

download_compatibility_tests(){
    # download the latest release of web ui (containing the compatibility tests) and extract to ${COMPATIBILITY_TESTS_DIR} (the directory will be deleted first)
    check_variable_is_set COMPATIBILITY_TESTS_DIR
    echo "Downloading compatibility tests"
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
    if [[ ! -e ${PERF_TESTS_DIR}/performance_tests_${PERF_TESTS_VERSION} ]]; then
        echo "Downloading performance tests"
        mkdir -p ${PERF_TESTS_DIR}
        cd ${PERF_TESTS_DIR}
        wget "${PERF_TESTS_URL}/${PERF_TESTS_VERSION}/htbhf-performance-tests-${PERF_TESTS_VERSION}-sources.jar" -q -O perf_tests.jar && jar -xf perf_tests.jar && rm perf_tests.jar
        touch performance_tests_${PERF_TESTS_VERSION}
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
