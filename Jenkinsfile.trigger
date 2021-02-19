#!/user/bin/env groovy
import org.jenkinsci.plugins.pipeline.modeldefinition.Utils
import org.jenkinsci.plugins.pipeline.modeldefinition.parser.JSONParser
/*
plugins used in Jenkinsfile
- Bitbucket Server Notifier (notifyBitbucket)
- XML test reports generated during the builds (junit)
- email notifications (emailext)
- Workspace Cleanup Plugin (cleanWs)
- org.jenkinsci.plugins.pipeline.modeldefinition.Utils to skipspecific stages
*/
node('docker_build') {

      properties([
        parameters([
            string(defaultValue: 'develop', description: 'Branch Name:', name: 'push_changes_0_new_name', trim: true),
            string(defaultValue: 'develop', description: 'PR Destination:', name: 'dest_branch', trim: true),
            string(defaultValue: 'develop', description: 'For internal Use:', name: 'global_packaging_branch', trim: true),
        ])
    ])

    def PW_BRANCH = "${push_changes_0_new_name}"
    def DEST_BRANCH = "${dest_branch}"
    def secrets = [
        [path: 'development/engsvcs/global-manifest-update', engineVersion: 2, secretValues: [[envVar: 'prPass', vaultKey: 'prPassword'],[envVar: 'prUser', vaultKey: 'prUser']]]

    ]
    def configuration = [vaultUrl: 'https://vault.parallelwireless.net',
                         vaultCredentialId: 'pwvault',
                         engineVersion: 2]
    withVault([configuration: configuration, vaultSecrets: secrets]) {
     timestamps {
        timeout(time: 3, unit: 'HOURS') {

        currentBuild.displayName = "${BUILD_NUMBER}:${repository_slug}:${PW_BRANCH}"
        println currentBuild.displayName
        currentBuild.description = "Build ${repository_slug} on branch: ${PW_BRANCH}"
        def verCode = UUID.randomUUID().toString()

        def repo_mirror_link = 'ssh://git@git.parallelwireless.net:7999/cd/global-manifest-update.git'

        def repo_link_map = [
            'pwconfig': 'ssh://git@git.parallelwireless.net:7999/cd/pwconfig.git',
            'core': 'ssh://git@git.parallelwireless.net:7999/cd/core.git' 
            ]

        def build_jobs = [
            'core': 'hng-pipeline',
            'pwconfig': 'pwconfig'
            ]
        
        def pull_api = ''
        def pull_req = ''
        def pull_list = []

        try {            
             stage ('Clone'){
               dir("${verCode}") {
                    def retryAttempt = 0
                    retry(2) {
                        if (retryAttempt > 0) {
                            sleep 60
                        }
                        retryAttempt = retryAttempt + 1
                        repo_link_map.each {mirror, mirror_link ->
                         
                         stage(mirror + " : Trigger manifest update"){
                            println mirror_link
                            println mirror 
                            sh """
                            pwd
                            rm -rf ${mirror}
                            git clone ${mirror_link}
                            pwd
                            """
                            dir("${mirror}") {
                                  
                                retValue = sh(returnStatus: true, script: "pwd")
                                retValue = sh(returnStatus: true, script: "git pull")
                                def retr_build_job = "global-manifest-update"
                                commit_hash = sh (returnStdout: true , script: "git rev-parse HEAD").trim()               
                  
                                build job: retr_build_job, parameters: [string(name: 'push_changes_0_new_name', value: String.valueOf(PW_BRANCH)), string(name: 'push_changes_0_new_target_hash', value: String.valueOf(commit_hash)), string(name: 'repository_slug', value: String.valueOf(mirror)), string(name: 'dest_branch', value: String.valueOf(DEST_BRANCH))], propagate: false, wait: false

                            }
                          }
                        }
                   }
               }
           }

        }
        catch (Exception Error) {
            currentBuild.result = 'FAILURE'
            throw Error
        }
        finally {
            cleanWs()
            notifyBitbucket(commitSha1:"$commit_hash")
         }
      }
   }
}
}
