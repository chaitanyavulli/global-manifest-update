#!/user/bin/env groovy
import org.jenkinsci.plugins.pipeline.modeldefinition.Utils
/*
plugins used in Jenkinsfile
- Bitbucket Server Notifier (notifyBitbucket)
- XML test reports generated during the builds (junit)
- email notifications (emailext)
- Workspace Cleanup Plugin (cleanWs)
- org.jenkinsci.plugins.pipeline.modeldefinition.Utils to skipspecific stages
*/
node('docker_build') {

    def PW_BRANCH = "${push_changes_0_new_name}"
    def NEW_COMMIT_HASH = "${push_changes_0_new_target_hash}"
    def PW_REPOSITORY = "${repository_slug}"

    timestamps {
        currentBuild.displayName = "${BUILD_NUMBER}:${repository_slug}:${PW_BRANCH}"
        println currentBuild.displayName
        currentBuild.description = "Build ${repository_slug} on branch: ${PW_BRANCH}"
        def verCode = UUID.randomUUID().toString()

        notifyBitbucket(commitSha1:"$NEW_COMMIT_HASH")
        
        def short_hash
        try {
             stage('Fetching Code') {
                dir("${verCode}") {
                    def retryAttempt = 0
                    retry(2) {
                        if (retryAttempt > 0) {
                            sleep 60
                        }
                        retryAttempt = retryAttempt + 1
                        milestone label: 'develop'
                        sh """
                        rm -rf ${PW_REPOSITORY}
                        mkdir ${PW_REPOSITORY}
                        cd ${PW_REPOSITORY}
                        git init
                        git remote add origin ssh://git@git.parallelwireless.net:7999/tool/uniperf.git
                        git fetch --depth 2 origin ${NEW_COMMIT_HASH}
                        git checkout FETCH_HEAD
                        """
                    } 
                }
                dir("${verCode}/${repository_slug}/") {
                    short_hash = sh (script: 'git rev-parse --short=8 HEAD',returnStdout: true).trim()
                }
            }
        
        stage('Change Packaging Repo') {
                dir("${verCode}/packaging-repo") {
                    checkout([
                        $class: 'GitSCM',
                        branches: [[name: 'origin/private/git-tag-test-branch']],
                        browser: [$class: 'BitbucketWeb',
                        repoUrl: 'https://git.parallelwireless.net/projects/CD/repos/global-packaging/browse'],
                        doGenerateSubmoduleConfigurations: false,
                        extensions: [],
                        submoduleCfg: [],
                        userRemoteConfigs: [[url: 'ssh://git@git.parallelwireless.net:7999/cd/global-packaging.git']]
                    ])
                    
                    sh("git checkout -b ltesim-tag-update-${short_hash}")
                    sh("sed -e 's/\"${PW_REPOSITORY}\": \".*\"/\"${PW_REPOSITORY}\": \"${short_hash}\"/' --in-place manifest.json") 
                    sh("git commit -m 'tag-update auto upgrade' manifest.json")
                    sh("git push --set-upstream origin ltesim-tag-update-${short_hash}")
                }
            }
            
        stage('Publish') {
                dir("${verCode}/${repository_slug}/${ci_dir}") {
                    catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
                     echo "Publish"
                    }
                }
            }


            currentBuild.result = 'SUCCESS'
        }
        catch (Exception Error) {
            currentBuild.result = 'FAILURE'
            throw Error
        }
        finally {
            cleanWs()
            notifyBitbucket(commitSha1:"$NEW_COMMIT_HASH")
            notifySuccessful()
        }
    }
}

def notifySuccessful() {
     emailext (
         attachLog: true,
         subject: "${env.JOB_NAME} Build #${env.BUILD_DISPLAY_NAME} status: ${currentBuild.result}",
         body: "HNG Functional test: ${env.JOB_NAME} Build #${env.BUILD_DISPLAY_NAME} status: ${currentBuild.result} <br> Check console output at ${env.BUILD_URL} to view the results",
         mimeType: 'text/html',
         recipientProviders: [developers(), requestor()]
    )
}
