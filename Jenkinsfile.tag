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

    properties([
        parameters([
            string(defaultValue: '', description: 'Branch Name:', name: 'push_changes_0_new_name', trim: true),
            string(defaultValue: '', description: 'Repository Name: (Possible values: access-product-packaging core nrtric rt-monitoring uniperf pwconfig core-stacks 2g-stack pnf-vnf core-stacks-phy vru-4g-phy bbpms_bsp vru-2g-phy vru-3g-phy nodeh cws-rrh osmo2g)', name: 'repository_slug', trim: true),
            string(defaultValue: '', description: 'New Hash:', name: 'push_changes_0_new_target_hash', trim: true),
            string(defaultValue: 'develop', description: 'For internal Use:', name: 'global_packaging_branch', trim: true),
        ])
    ])

    def PW_BRANCH = "${push_changes_0_new_name}"
    def NEW_COMMIT_HASH = "${push_changes_0_new_target_hash}"
    def PW_REPOSITORY = "${repository_slug}"

    timestamps {
        timeout(time: 3, unit: 'HOURS') {

        currentBuild.displayName = "${BUILD_NUMBER}:${repository_slug}:${PW_BRANCH}"
        println currentBuild.displayName
        currentBuild.description = "Build ${repository_slug} on branch: ${PW_BRANCH}"
        def verCode = UUID.randomUUID().toString()

        notifyBitbucket(commitSha1:"$NEW_COMMIT_HASH")

        def trigger_downstream_job = true
        def git_remotes = [
            'access-product-packaging': 'ssh://git@git.parallelwireless.net:7999/cd/access-product-packaging.git',
            'core': 'ssh://git@git.parallelwireless.net:7999/cd/core.git',
            'nrtric': 'ssh://git@git.parallelwireless.net:7999/cd/cloudapps.git',
            'rt-monitoring': 'ssh://git@git.parallelwireless.net:7999/da/rt-monitoring.git',
            'uniperf': 'ssh://git@git.parallelwireless.net:7999/tool/uniperf.git',
            'pwconfig': 'ssh://git@git.parallelwireless.net:7999/cd/pwconfig.git',
            'core-stacks': 'ssh://git@git.parallelwireless.net:7999/cd/core-stacks.git',
            '2g-stack': 'ssh://git@git.parallelwireless.net:7999/cd/2g-stack.git',
            'pnf-vnf': 'ssh://git@git.parallelwireless.net:7999/cd/pnf-vnf.git',
            'core-stacks-phy': 'ssh://git@git.parallelwireless.net:7999/cd/core-stacks-phy.git',
            'vru-4g-phy': 'ssh://git@git.parallelwireless.net:7999/cd/vru-4g-phy.git',
            'bbpms_bsp': 'ssh://git@git.parallelwireless.net:7999/bsp/bbpms_bsp.git',
            'vru-2g-phy': 'ssh://git@git.parallelwireless.net:7999/cd/vru-2g-phy.git',
            'vru-3g-phy': 'ssh://git@git.parallelwireless.net:7999/cd/vru-3g-phy.git',
            'nodeh': 'ssh://git@git.parallelwireless.net:7999/cd/nodeh.git',
            'cws-rrh': 'ssh://git@git.parallelwireless.net:7999/cd/cws-rrh.git',
            'osmo2g': 'ssh://git@git.parallelwireless.net:7999/cd/osmo2g.git'
            ]
        def ci_tag = "ci-${PW_REPOSITORY}-${PW_BRANCH}-${NEW_COMMIT_HASH[0..9]}"
        println ci_tag
        try {
             stage('Fetch Code') {
                dir("${verCode}") {
                    def retryAttempt = 0
                    def mirror = git_remotes[PW_REPOSITORY]
                    println mirror
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
                        git remote add origin ${mirror}
                        git fetch
                        """
                    } 
                }
            }
        
        stage('Tag Git Repo') {
                dir("${verCode}/${PW_REPOSITORY}") {
                    retValue = sh(returnStatus:true, script: "git tag -a ${ci_tag} -m \"Automated Tag\" ${NEW_COMMIT_HASH}")
                    if (retValue == 128){
                        println "Tag already present"
                    }
                    sh(returnStatus:true, script: "git push origin --tags")
                }
            }
        stage('Trigger Downstream Job Manifest File Update') {
                dir("${verCode}/${PW_REPOSITORY}") {
                    if ( trigger_downstream_job == true ) {
                     build job: 'manifest-file-update', parameters: [string(name: 'push_changes_0_new_name', value: String.valueOf(PW_BRANCH)), string(name: 'push_changes_0_new_target_hash', value: String.valueOf(push_changes_0_new_target_hash)), string(name: 'repository_slug', value: String.valueOf(repository_slug))], propagate: false, wait: false
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
        }
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
