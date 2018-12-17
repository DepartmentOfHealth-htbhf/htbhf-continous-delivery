#!/bin/bash

# if this is a pull request or branch (non-master) build, then just exit
echo "TRAVIS_PULL_REQUEST=$TRAVIS_PULL_REQUEST, TRAVIS_BRANCH=$TRAVIS_BRANCH"
if [[ "$TRAVIS_PULL_REQUEST" != "false"  || "$TRAVIS_BRANCH" != "master" ]]; then
   echo "Not deploying pull request or branch build"
   exit
fi

check_variable_is_set(){
    if [[ -z ${!1} ]]; then
        echo "$1 must be set and non empty"
        exit 1
    fi
}

check_variable_is_set DEPLOY_SCRIPTS_URL
check_variable_is_set DEPLOY_SCRIPT_VERSION
check_variable_is_set BIN_DIR
check_variable_is_set PERF_TESTS_URL
check_variable_is_set PERF_TESTS_VERSION
check_variable_is_set PERF_TESTS_DIRECTORY
check_variable_is_set GH_WRITE_TOKEN
check_variable_is_set TRAVIS_REPO_SLUG

export BIN_DIR=$(readlink -f ${BIN_DIR})

if [[ ! -e ${BIN_DIR}/deploy_scripts_${DEPLOY_SCRIPT_VERSION} ]]; then
  echo "Installing deploy scripts"
    mkdir -p ${BIN_DIR}
    cd ${BIN_DIR}
    wget "${DEPLOY_SCRIPTS_URL}/${DEPLOY_SCRIPT_VERSION}.zip" -q -O deploy_scripts.zip && unzip -j -o deploy_scripts.zip && rm deploy_scripts.zip
    touch deploy_scripts_${DEPLOY_SCRIPT_VERSION}
    cd ..
fi


echo "Determining whether to deploy node or java application (Node if ZIP_URL is set: '$ZIP_URL')"
if [[ ${ZIP_URL} ]]; then
    echo "Deploying Node.js app from '${ZIP_URL}'"
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
else
    echo "Deploying Java app from '${APP_URL}' using manifest from '${MANIFEST_URL}'"
    check_variable_is_set APP_URL
    check_variable_is_set MANIFEST_URL

    wget -q -O artefact.jar ${APP_URL}
    wget -q -O manifest.jar ${MANIFEST_URL}
    # extract the manifest into the current directory
    jar -xf manifest.jar
    export APP_PATH=artefact.jar
fi


export CF_SPACE=staging

/bin/bash ${BIN_DIR}/deploy.sh
DEPLOY_RESULT=$?

if [[ ${DEPLOY_RESULT} != 0 ]]; then
  echo "Deployment failed, exiting."
  exit ${DEPLOY_RESULT}
fi

if [[ ! -e ${PERF_TESTS_DIRECTORY}/performance_tests_${PERF_TESTS_VERSION} ]]; then
  echo "Downloading performance tests"
  mkdir -p ${PERF_TESTS_DIRECTORY}
  cd ${PERF_TESTS_DIRECTORY}
  wget "${PERF_TESTS_URL}/${PERF_TESTS_VERSION}/htbhf-performance-tests-${PERF_TESTS_VERSION}-sources.jar" -q -O perf_tests.jar && jar -xf perf_tests.jar && rm perf_tests.jar
  touch performance_tests_${PERF_TESTS_VERSION}
  cd ..
fi

export ROOT_PATH=`pwd`
echo "Running performance tests"
/bin/bash ${PERF_TESTS_DIRECTORY}/run_performance_tests.sh
/bin/bash ./cd_scripts/publish_test_results.sh