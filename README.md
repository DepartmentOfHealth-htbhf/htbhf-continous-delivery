#continuous-delivery

Contains the (bash) scripts to deploy a given artefact to staging, run tests, then deploy to production. 
Triggered by individual build (CI) scripts on success - 
to trigger from a CI build, use either `trigger_java_cd_build.sh` or `trigger_node_cd_build.sh`, available in the 
[htbhf-deployment-scripts](https://github.com/DepartmentOfHealth-htbhf/htbhf-deployment-scripts) project.
For example add this to the .travis.yml file of a java project:
```
after_success:
- test $TRAVIS_BRANCH = "master" && test $TRAVIS_PULL_REQUEST = "false" && ./${BIN_DIR}/deployment-scripts/trigger_java_cd_build.sh

```
(This assumes that the deployment scripts are already in use by your project).

The CD build can also be triggered via the travis-ci REST API - 
the nightly build and weekly soak test are triggered in this fashion by [cron-job.org](https://cron-job.org/en/members/)
(credentials are in web-accounts.yml in 1Password).


## Local Usage
To run the script locally, the following environment variables must be set
* APP_URL (url of the application to deploy)
* MANIFEST_URL (url of the application's cloud foundry manifest)
* DEPLOY_SCRIPTS_URL
* DEPLOY_SCRIPT_VERSION
* BIN_DIR (directory to install deploy scripts)
* SMOKE_TESTS (path to smoke tests script used to test that deployment was successful)
* PERF_TESTS_URL 
* PERF_TESTS_VERSION

