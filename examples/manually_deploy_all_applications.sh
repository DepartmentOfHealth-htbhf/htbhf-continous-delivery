#!/bin/bash

# script to deploy applications into an empty space.
# Note that this does not deploy any stub applications (smart stub or os places) so the applications
# should be configured to connect to those stubs.
# It is assumed that the create_services.sh script has already been run to provision the space.

######################
# function definitions
######################

pause(){
    read -p "Press [Enter] key to continue..."
}

check_variable_is_set(){
    if [[ -z ${!1} ]]; then
        echo "$1 must be set and non empty. ($2)"
        exit 1
    fi
}

manual_deploy_java_app() {
  check_variable_is_set APP_NAME
  check_variable_is_set APP_VERSION

  GITHUB_REPO_SLUG=DepartmentOfHealth-htbhf/${APP_NAME}
  APP_URL=${BINTRAY_ROOT_URL}/${APP_NAME}/${APP_VERSION}/${APP_NAME}-${APP_VERSION}.jar
  MANIFEST_URL=${BINTRAY_ROOT_URL}/${APP_NAME}-manifest/${APP_VERSION}/${APP_NAME}-manifest-${APP_VERSION}.jar
  CF_DOMAIN=london.cloudapps.digital

  unset ZIP_URL

  echo "Deploying ${APP_NAME} version ${APP_VERSION} to ${CF_SPACE}"
  pause
  deploy_application
}

manual_deploy_node_app() {
  check_variable_is_set APP_NAME
  check_variable_is_set APP_VERSION
  check_variable_is_set REPO_NAME

  GITHUB_REPO_SLUG=DepartmentOfHealth-htbhf/${REPO_NAME}
  ZIP_URL="https://github.com/${GITHUB_REPO_SLUG}/archive/v${APP_VERSION}.zip"
  CF_DOMAIN=apps.internal

  echo "Deploying ${APP_NAME} from ${REPO_NAME} version ${APP_VERSION} to ${CF_SPACE}"
  pause
  deploy_application
}

#####################
# Variable definition
#####################
check_variable_is_set CF_SPACE
check_variable_is_set BASE_DIR "The parent directory of the continuous delivery project"
export CD_SCRIPTS_DIR="${BASE_DIR}/htbhf-continous-delivery/cd_scripts"
export WORKING_DIR="${BASE_DIR}/temp-deploy"
export BIN_DIR="${WORKING_DIR}/bin"
export BINTRAY_ROOT_URL=https://dl.bintray.com/departmentofhealth-htbhf/maven/uk/gov/dhsc/htbhf


# get versions of code to deploy from: https://departmentofhealth-htbhf.github.io/htbhf-continous-delivery/docs/production_app_versions.txt
wget -q https://departmentofhealth-htbhf.github.io/htbhf-continous-delivery/docs/production_app_versions.txt
cat production_app_versions.txt | tr '-' '_' | tr '[:lower:]' '[:upper:]' | sed -e 's/\([A-Z0-9_]*\):\s*/export \1_VERSION=/g' > set_app_versions.sh
source ./set_app_versions.sh

check_variable_is_set APPLY_FOR_HEALTHY_START_VERSION
check_variable_is_set HTBHF_CARD_SERVICES_API_VERSION
check_variable_is_set HTBHF_CLAIMANT_SERVICE_VERSION
check_variable_is_set HTBHF_DWP_API_VERSION
check_variable_is_set HTBHF_HMRC_API_VERSION
check_variable_is_set HTBHF_ELIGIBILITY_SERVICE_VERSION



################
# Run the script
################
source "${CD_SCRIPTS_DIR}/cd_functions.sh"

echo "Creating working directory ${WORKING_DIR}"
mkdir -p "${WORKING_DIR}"
cd "${WORKING_DIR}"

download_deploy_scripts

echo "About to deploy applications into ${CF_SPACE}. Please note that some add-network-policy commands will fail during initial deployments, until both applications the network policy applies to are present. This is expected."
pause

# web-ui
APP_NAME=apply-for-healthy-start
REPO_NAME=htbhf-applicant-web-ui
APP_VERSION=${APPLY_FOR_HEALTHY_START_VERSION}
manual_deploy_node_app

# claimant-service
APP_NAME=htbhf-claimant-service
APP_VERSION=${HTBHF_CLAIMANT_SERVICE_VERSION}
manual_deploy_java_app

# eligibility-service
APP_NAME=htbhf-eligibility-service
APP_VERSION=${HTBHF_ELIGIBILITY_SERVICE_VERSION}
manual_deploy_java_app

# dwp-api
APP_NAME=htbhf-dwp-api
APP_VERSION=${HTBHF_DWP_API_VERSION}
manual_deploy_java_app

# hmrc-api
APP_NAME=htbhf-hmrc-api
APP_VERSION=${HTBHF_HMRC_API_VERSION}
manual_deploy_java_app

# card-services-api
APP_NAME=htbhf-card-services-api
APP_VERSION=${HTBHF_CARD_SERVICES_API_VERSION}
manual_deploy_java_app


