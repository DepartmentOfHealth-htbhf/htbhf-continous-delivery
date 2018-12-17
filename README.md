#continuous-delivery

Contains the scripts to deploy a given artefact to staging.

## Usage
To run the script locally, the following environment variables must be set
* APP_URL (url of the application to deploy)
* MANIFEST_URL (url of the application's cloud foundry manifest)
* DEPLOY_SCRIPTS_URL
* DEPLOY_SCRIPT_VERSION
* BIN_DIR (directory to install deploy scripts)
* SMOKE_TESTS (path to smoke tests script used to test that deployment was successful)
* PERF_TESTS_URL 
* PERF_TESTS_VERSION

To trigger from a CI build

TODO add api example once tested.