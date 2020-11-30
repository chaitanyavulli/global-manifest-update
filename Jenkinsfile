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
        def branch_name
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
                        git fetch
                        """
                    } 
                }
                dir("${verCode}/${repository_slug}/") {
                    branch_name = sh (script: "git branch --contains ${PW_BRANCH} -a | tail -n 1 | sed 's/.*remotes\\/origin\\///'",returnStdout: true).trim()
                    println branch_name
                }
            }
        
        stage('Change Packaging Repo') {
                dir("${verCode}/packaging-repo") {
                    checkout([
                        $class: 'GitSCM',
                        branches: [[name: 'develop']],
                        browser: [$class: 'BitbucketWeb',
                        repoUrl: 'https://git.parallelwireless.net/projects/CD/repos/integrated-packaging/browse'],
                        doGenerateSubmoduleConfigurations: false,
                        extensions: [],
                        submoduleCfg: [],
                        userRemoteConfigs: [[url: 'ssh://git@git.parallelwireless.net:7999/cd/integrated-packaging.git']]
                    ])
                    
                    sh("git checkout -b integ/${branch_name}")
                    sh("git branch --set-upstream-to=origin/integ/${branch_name} integ/${branch_name}")
                    sh("git pull")
                    sh("sed -e 's/\"${PW_REPOSITORY}\": \".*\"/\"${PW_REPOSITORY}\": \"${NEW_COMMIT_HASH}\"/' --in-place manifest.json") 
                    sh("git commit -m 'tag-update commitID auto upgrade' manifest.json")
                    sh("git push --set-upstream origin integ/${branch_name}")
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
         subject: "Manifest file updated",
         body: "Manifest file updated",
         mimeType: 'text/html',
         recipientProviders: [developers(), requestor()]
    )
}
