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
    if [[ ! -e ${BIN_DIR}/deploy_scripts_${DEPLOY_SCRIPT_VERSION} ]]; then
        echo "Installing deploy scripts"
        mkdir -p ${BIN_DIR}
        cd ${BIN_DIR}
        wget "${DEPLOY_SCRIPTS_URL}/${DEPLOY_SCRIPT_VERSION}.zip" -q -O deploy_scripts.zip && unzip -j -o deploy_scripts.zip && rm deploy_scripts.zip
        touch deploy_scripts_${DEPLOY_SCRIPT_VERSION}
        cd ..
    fi
}

download_compatibility_tests(){
    if [[ ! -e ${COMPATIBILITY_TESTS_DIR}/performance_tests_${COMPATIBILITY_TESTS_VERSION} ]]; then
        echo "Downloading compatibility tests"
        mkdir -p ${COMPATIBILITY_TESTS_DIR}
        cd ${COMPATIBILITY_TESTS_DIR}
        wget "${COMPATIBILITY_SCRIPTS_URL}/${COMPATIBILITY_SCRIPT_VERSION}.zip" -q -O compatibility_scripts.zip && unzip -j -o compatibility_scripts.zip && rm compatibility_scripts.zip
        touch compatibility_tests_${COMPATIBILITY_TESTS_VERSION}
        cd ..
    fi
}

download_performance_tests(){
    if [[ ! -e ${PERF_TESTS_DIR}/performance_tests_${PERF_TESTS_VERSION} ]]; then
        echo "Downloading performance tests"
        mkdir -p ${PERF_TESTS_DIR}
        cd ${PERF_TESTS_DIR}
        wget "${PERF_TESTS_URL}/${PERF_TESTS_VERSION}/htbhf-performance-tests-${PERF_TESTS_VERSION}-sources.jar" -q -O perf_tests.jar && jar -xf perf_tests.jar && rm perf_tests.jar
        touch performance_tests_${PERF_TESTS_VERSION}
        cd ..
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