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

        def repo_mirror_link = 'ssh://git@git.parallelwireless.net:7999/cd/global-manifest-update.git'

        def manifest_map = [
            'access-product-packaging': ['integrated-packaging'],
            'core': ['access-product-packaging','integrated-packaging'],
            'nrtric': ['integrated-packaging'],
            'rt-monitoring': ['integrated-packaging'],
            'uniperf': ['integrated-packaging'],
            'pwconfig': ['integrated-packaging'],
            'core-stacks': ['access-product-packaging'],
            '2g-stack': ['access-product-packaging'],
            'pnf-vnf': ['access-product-packaging'],
            'core-stacks-phy': ['access-product-packaging'],
            'vru-4g-phy': ['access-product-packaging'],
            'bbpms_bsp': ['access-product-packaging'],
            'vru-2g-phy': ['access-product-packaging'],
            'vru-3g-phy': ['access-product-packaging'],
            'nodeh': ['access-product-packaging'],
            'cws-rrh': ['access-product-packaging'],
            'osmo2g': ['access-product-packaging']
            ]

        def build_jobs = [
            'core': 'hng-pipeline',
            'pwconfig': 'pwconfig'
            ]

        def pull_remote = [
            'access-product-packaging'  : 'https://git.parallelwireless.net/rest/api/1.0/projects/CD/repos/access-product-packaging/pull-requests',
            'integrated-packaging'      : 'https://git.parallelwireless.net/rest/api/1.0/projects/CD/repos/integrated-packaging/pull-requests'
            ]


        def mirror = ''
        def pull_api = ''
        def pull_req = ''
        def pull_list = []
        def ci_tag = "ci-${PW_REPOSITORY}-${PW_BRANCH}-${NEW_COMMIT_HASH[0..9]}"
        println ci_tag

        try {
             stage('Fetch Code') {
                dir("${verCode}") {
                    def retryAttempt = 0
                    mirror = git_remotes[PW_REPOSITORY]
                    println mirror
                    retry(2) {
                        if (retryAttempt > 0) {
                            sleep 60
                        }
                        retryAttempt = retryAttempt + 1
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
       
            stage ('Clone'){
               dir("${verCode}") {
                    def retryAttempt = 0
                    retry(2) {
                        if (retryAttempt > 0) {
                            sleep 60
                        }
                        retryAttempt = retryAttempt + 1
                            sh """
                            pwd
                            rm -rf global-packaging
                            mkdir global-packaging
                            cd global-packaging
                            git init
                            git remote add origin ${repo_mirror_link}
                            git fetch
                            git checkout -b ${global_packaging_branch}
                            git pull origin ${global_packaging_branch}
                            """
                   }
               }
            }

            stage ('Check Artifact'){
                 dir("${verCode}/global-packaging") {

                     def retValue = null
                     def ret_data = null

                     try {

                        //retValue = sh(returnStatus: true, script: "python getArtifact.py ${NEW_COMMIT_HASH} ${PW_BRANCH}")
                        retValue = sh(returnStdout: true, script: "curl -s https://pwartifactory.parallelwireless.net/artifactory/api/search/prop?commitID=${NEW_COMMIT_HASH}")
                        if ( retValue == "")
                            retValue = sh(returnStdout: true, script: "curl -s https://pwartifactory.parallelwireless.net/artifactory/api/search/prop?commitID=${NEW_COMMIT_HASH}")

                        ret_data = readJSON text:retValue.toString(),returnPojo: true
                     }
                     catch(Exception ex) {

                        println "Exception occure"
                        throw ex
                     }

                     if (ret_data["results"].isEmpty() != false) {

                         println "Artifact is not present. Re-Triggering the pipeline."
                         def retr_build_job = build_jobs[PW_REPOSITORY]

                         build job: retr_build_job, parameters: [string(name: 'push_changes_0_new_name', value: String.valueOf(PW_BRANCH)), string(name: 'push_changes_0_new_target_hash', value: String.valueOf(NEW_COMMIT_HASH)), string(name: 'repository_slug', value: String.valueOf(PW_REPOSITORY))], propagate: false, wait: false

                     } else {

                         println "Artifact is present."
                     }
                 }
            }

             stage('Update Manifest Files') {
                dir("${verCode}") {
                    def retryAttempt = 0
                    retry(2) {
                        if (retryAttempt > 0) {
                            sleep 60
                        }
                        retryAttempt = retryAttempt + 1
                        def remotes = manifest_map[PW_REPOSITORY]
                        remotes.each{remote ->
                            mirror= git_remotes[remote]
                            pull_api = pull_remote[remote]
                            sh """
                            pwd
                            rm -rf ${remote}
                            mkdir ${remote}
                            cd ${remote}
                            git init
                            git remote add origin ${mirror}
                            git fetch
                            """

                            dir("${remote}"){
                                retValue = sh(returnStatus: true, script: "pwd")
                                retValue = sh(returnStatus: true, script: "git checkout -b ${INTEG_BRANCH}")
                                retValue = sh(returnStatus: true, script: "git pull origin ${INTEG_BRANCH}")
                                println retValue
                                if (retValue == 1){
                                    println "Branch not present. Pulling from develop"
                                }
                                retValue = sh(returnStatus: true, script: "git pull origin develop")
                                sh(returnStatus: true, script: "sed -e 's/\"${PW_REPOSITORY}\": \".*\"/\"${PW_REPOSITORY}\": \"${NEW_COMMIT_HASH}\"/' --in-place manifest.json")
                                sh(returnStatus: true, script: "git commit -m 'tag-update commitID auto upgrade' manifest.json")
                                sh(returnStatus: true, script: "git push --set-upstream origin ${INTEG_BRANCH}")
                                pull_req = sh( returnStdout : true, script: "sh ../global-packaging/PullReqfile.sh ${INTEG_BRANCH} develop ${pull_api} ${remote} ${remote}").trim()
                                println pull_req
                                def props = readJSON text:pull_req.toString(),returnPojo: true

                                if ( props['errors'] != null ){
                                   println props.errors[0].existingPullRequest.links.self[0].href
                                   pull_list.add(props.errors[0].existingPullRequest.links.self[0].href)
                                } else { println props.links.self[0].href
                                   pull_list.add(props.links.self[0].href)
                                }
                            }
                        }
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
