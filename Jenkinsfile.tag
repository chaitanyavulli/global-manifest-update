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

import groovy.json.JsonSlurper

node('k8s && small && usnh') {

    properties([
        buildDiscarder(
            logRotator(artifactDaysToKeepStr: '', artifactNumToKeepStr: '', daysToKeepStr: '10', numToKeepStr: '')
        ),
        parameters([
            string(defaultValue: '', description: 'Branch Name:', name: 'push_changes_0_new_name', trim: true),
            string(defaultValue: '', description: 'Repository Name: (Possible values: access-product-packaging core nrtric pwgui rt-monitoring uniperf pwconfig core-stacks 2g-stack pnf-vnf core-stacks-phy vru-4g-phy bbpms_bsp vru-2g-phy vru-3g-phy nodeh cws-rrh osmo2g access-iso near_rtric access-common)', name: 'repository_slug', trim: true),
            string(defaultValue: '', description: 'New Hash:', name: 'push_changes_0_new_target_hash', trim: true),
            string(defaultValue: '', description: 'PR Destination:', name: 'dest_branch', trim: true),
            string(defaultValue: 'develop', description: 'For internal Use:', name: 'global_packaging_branch', trim: true),
        ])
    ])

    def PW_BRANCH = "${push_changes_0_new_name}"
    def NEW_COMMIT_HASH = "${push_changes_0_new_target_hash}"
    def PW_REPOSITORY = "${repository_slug}"
    def INTEG_BRANCH = "private/${PW_REPOSITORY}/${PW_BRANCH}"
    def DEST_BRANCH = "${dest_branch}"
    def buildUser = getBuildUser()
    def packagingJob = getUpstreamJob()
    def secrets = [
        [path: 'development/engsvcs/global-manifest-update', engineVersion: 2, secretValues: [[envVar: 'prPass', vaultKey: 'prPassword'],[envVar: 'prUser', vaultKey: 'prUser']]]

    ]
    def configuration = [vaultUrl: 'https://vault.parallelwireless.net',
                         vaultCredentialId: 'pwjenkins_vault',
                         engineVersion: 2]
    withVault([configuration: configuration, vaultSecrets: secrets]) {
    timestamps {
        timeout(time: 1, unit: 'HOURS') {

        currentBuild.displayName = "${BUILD_NUMBER}:${repository_slug}:${PW_BRANCH}"
        println currentBuild.displayName
        currentBuild.description = "Build ${repository_slug} on branch: ${PW_BRANCH}"
        def verCode = UUID.randomUUID().toString()

        def trigger_downstream_job = true
        def git_remotes = [
            'access-product-packaging': 'ssh://git@git.parallelwireless.net:7999/cd/access-product-packaging.git',
            'integrated-packaging': 'ssh://git@git.parallelwireless.net:7999/cd/integrated-packaging.git',
            'core': 'ssh://git@git.parallelwireless.net:7999/cd/core.git',
            'nrtric': 'ssh://git@git.parallelwireless.net:7999/cd/cloudapps.git',
            'rt-monitoring': 'ssh://git@git.parallelwireless.net:7999/da/rt-monitoring.git',
            'uniperf': 'ssh://git@git.parallelwireless.net:7999/tool/uniperf.git',
            'pwgui': 'ssh://git@nhbbm.parallelwireless.net:7999/git/cd/pwgui.git', 
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
            'osmo2g': 'ssh://git@git.parallelwireless.net:7999/cd/osmo2g.git',
            'access-iso': 'ssh://git@git.parallelwireless.net:7999/pwis/access-iso.git',
            'pwems-platform': 'ssh://git@git.parallelwireless.net:7999/cd/pwems-platform.git',
            'pwems-product-packaging': 'ssh://git@git.parallelwireless.net:7999/cd/pwems-product-packaging.git',
            'network': 'ssh://git@git.parallelwireless.net:7999/cd/network.git',
            'vru-5g-phy': 'ssh://git@git.parallelwireless.net:7999/cd/vru-5g-phy.git',
            'nr-stack': 'ssh://git@git.parallelwireless.net:7999/cd/nr-stack.git',
            'near_rtric': 'ssh://git@git.parallelwireless.net:7999/near/near_rtric.git',
            'access-common': 'ssh://git@git.parallelwireless.net:7999/cd/access-common.git',
	        '3rd-party-pkgs': 'ssh://git@git.parallelwireless.net:7999/cd/3rd-party-pkgs.git'
        ]

        def repo_mirror_link = 'ssh://git@git.parallelwireless.net:7999/cd/global-manifest-update.git'

        def manifest_map = [
            'access-product-packaging': ['integrated-packaging'],
            'core': [packagingJob],
            'nrtric': ['integrated-packaging'],
            'rt-monitoring': ['pwems-product-packaging'],
            'uniperf': ['integrated-packaging'],
            'pwgui': ['pwems-product-packaging'],
            'pwconfig': ['pwems-product-packaging'],
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
            'osmo2g': ['access-product-packaging'],
            'access-iso': ['access-product-packaging'],
            'pwems-platform': ['pwems-product-packaging'],
            'network': ['integrated-packaging'],
            'pwems-product-packaging': ['integrated-packaging'],
            'vru-5g-phy': ['access-product-packaging'],
            'nr-stack': ['access-product-packaging'],
            'near_rtric': ['integrated-packaging'],
            'access-common': ['access-product-packaging'],
	        '3rd-party-pkgs':['integrated-packaging']
        ]

        def build_jobs = [
            'core': 'hng-pipeline',
            'pwconfig': 'pwconfig'
            ]

        def pull_remote = [
            'access-product-packaging'  : 'https://git.parallelwireless.net/rest/api/1.0/projects/CD/repos/access-product-packaging/pull-requests',
            'integrated-packaging'      : 'https://git.parallelwireless.net/rest/api/1.0/projects/CD/repos/integrated-packaging/pull-requests',
            'pwems-product-packaging'   : 'https://git.parallelwireless.net/rest/api/1.0/projects/CD/repos/pwems-product-packaging/pull-requests'
            ]

        def relnum_remote = [
            'access-product-packaging'  : 'https://git.parallelwireless.net/rest/api/1.0/projects/cd/repos/access-product-packaging/raw/relnum.txt?at=',
            'network'                   : 'https://git.parallelwireless.net/rest/api/1.0/projects/cd/repos/network/raw/hng/relnum.txt?at=',
            'pwems-product-packaging'   : 'https://git.parallelwireless.net/rest/api/1.0/projects/cd/repos/pwems-product-packaging/raw/relnum.txt?at='
        ]

        //special case for platdev-multi-rat - we wish to create 2 PRs - where the second one will point to feature/platdev-multi-rat
        def MULTI_RAT = false
	/*
        if (( DEST_BRANCH == "integ/6_2_dev") && ( PW_REPOSITORY == "2g-stack" || PW_REPOSITORY == "osmo2g" )){
            MULTI_RAT = true
        }
        if (( DEST_BRANCH == "develop") && ( PW_REPOSITORY == "core-stacks" || PW_REPOSITORY == "nodeh" || PW_REPOSITORY == "core-stacks-phy" )){
            MULTI_RAT = true
        }
	*/
        //special case: access-product-packaging,network,pwems-product-packaging  release/REL_6.2.x onwards , integrated-packaging = release/REL_6.2. 0,1,2,3,4...
        //              updating the destination branch according to the relnum file in the source repo
        if (( DEST_BRANCH ==~ /^release\/REL_\d(.*)x$/ ) && ( PW_REPOSITORY == "access-product-packaging" || PW_REPOSITORY == "network" || PW_REPOSITORY == "pwems-product-packaging" )){
            def packaging_repo = manifest_map[PW_REPOSITORY][0]
            def relnum_repo = relnum_remote[PW_REPOSITORY]
            sh(script: "curl -u ${prUser}:${prPass} -X GET -H Content-Type:application/json $relnum_repo$DEST_BRANCH -o relnum.txt")
            sh(script: "cat relnum.txt")
            def release_num = sh(returnStdout : true,
                script: "sed -n '/RELEASE_NUM/p' relnum.txt | tr -d ' ' | cut -d'=' -f2").trim()
            DEST_BRANCH = "release/REL_$release_num"
            echo "Destination branch is $DEST_BRANCH"
            retValue = sh(returnStatus: true, script: "git ls-remote --exit-code --heads ssh://git@git.parallelwireless.net:7999/cd/${packaging_repo} refs/heads/$DEST_BRANCH")
            if ( retValue != 0 ){
                echo "ERROR: relnum file not found or release number is not found in bitbucket... exiting..."
                currentBuild.result = 'FAILURE'
                notifyFailure()
                return
            }
        }

        //special case: access-packaging = release/REL_vBBU_6.1.x , hng = release/REL_HNG_6.1.x , integrated-packaging = release/REL_6.1.x
        //x can be 0,1,2,3,4,5...
        if (( DEST_BRANCH.startsWith("release/REL_vBBU_6.1.") && PW_REPOSITORY == "access-product-packaging" ) || ( DEST_BRANCH.startsWith("release/REL_HNG_6.1.") && PW_REPOSITORY == "core" )){
            if (( DEST_BRANCH.startsWith("release/REL_vBBU_6.1.1.") && PW_REPOSITORY == "access-product-packaging" ) || ( DEST_BRANCH.startsWith("release/REL_HNG_6.1.1.") && PW_REPOSITORY == "core" )){
                echo "Changing the destination branch to be release/REL_6.1.1. and the last char of the branch provided"
                DEST_BRANCH = "release/REL_6.1.1."+DEST_BRANCH[-1]
            } else {
                echo "Changing the destination branch to be release/REL_6.1. and the last char of the branch provided"
                DEST_BRANCH = "release/REL_6.1."+DEST_BRANCH[-1]
            }
            println DEST_BRANCH
        }

        if ( DEST_BRANCH == "develop" || DEST_BRANCH.startsWith("integ") || DEST_BRANCH.startsWith("feature") || DEST_BRANCH.startsWith("release")){
            def packaging_repo = manifest_map[PW_REPOSITORY][0]
            retValue = sh(returnStatus: true, script: "git ls-remote --exit-code --heads ssh://git@git.parallelwireless.net:7999/cd/${packaging_repo} refs/heads/${DEST_BRANCH}")
            if ( retValue == 0 ){
                echo "Destination branch found in the ${packaging_repo} repo - Continue."
            } else {
                echo "Destination branch is ${DEST_BRANCH} - does not exist on the packaging repo - stopping."
                currentBuild.result = 'SUCCESS'
                return
            }
        } else {
            echo "Destination branch is ${DEST_BRANCH} - is not part of the governed branches - stopping."
            currentBuild.result = 'SUCCESS'
            return
        }

        notifyBitbucket(commitSha1:"$NEW_COMMIT_HASH")
        def mirror = ''
        def pull_api = ''
        def pull_req = ''
        def pull_list = []
        def ci_tag = "ci-${PW_REPOSITORY}-${PW_BRANCH}-${NEW_COMMIT_HASH[0..9]}"
        println ci_tag

        try {
             stage('Clone Upstream Repo') {
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
                        git fetch --no-tags
                        """
                    } 
                 }
             }
             /*
             stage('Tag Upstream Commit') {
                dir("${verCode}/${PW_REPOSITORY}") {
                    retValue = sh(returnStatus:true, script: "git tag -a ${ci_tag} -m \"Automated Tag created by ${buildUser} for commit Hash: \" ${NEW_COMMIT_HASH}")
                    if (retValue == 128){
                        println "Tag already present"
                    }
                    sh(returnStatus:true, script: "git push origin --tags")
                }
             }
             */
             stage('Upstream commit message') {
                dir("${verCode}/${PW_REPOSITORY}") {
                    env.GIT_COMMIT_MSG = sh(returnStdout:true, script: "echo ${PW_REPOSITORY} commit message is: `git log --pretty=format:%B -n 1 ${NEW_COMMIT_HASH} | tail -1`").trim()
                    echo "${env.GIT_COMMIT_MSG}"
                    env.GIT_COMMIT_MSG="${GIT_COMMIT_MSG}".replace("\"", "") //Remove any double quotes for the JSON pull request creation
                    env.GIT_COMMIT_MSG="${GIT_COMMIT_MSG}".replace("\'", "") //Remove any single quotes for the JSON pull request creation
                    env.GIT_COMMIT_MSG="${GIT_COMMIT_MSG}".take(200) //Please enter a non-empty value less than 255 characters
                    env.AUTHOR_EMAIL = sh(returnStdout:true, script: "git log --format='%ae' -n 1 ${NEW_COMMIT_HASH}").trim()
                    echo "${env.AUTHOR_EMAIL}"
                }
             }
             stage ('Clone global-manifest-update Repo'){
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
            stage ('Check Upstream Artifact'){
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
                        notifyFailure()
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
                        def dest_branches = ["${DEST_BRANCH}"]
                        if (MULTI_RAT){
                            println "MULTI_RAT is on"
                            dest_branches = ["${DEST_BRANCH}","feature/platdev-multi-rat"]
                        }
                        dest_branches.each{dst_branch ->
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
                                sh(returnStatus: true, script: "pwd")
                                sh(returnStatus: true, script: "git checkout -b ${INTEG_BRANCH} origin/${dst_branch}")
                                
                                def CURRENT_COMMIT_HASH = ""
                                def currentTimestamp = ""
                                def newTimestamp = ""

                                def data = readJSON file: "manifest.json"
                                    println "data: $data"
                                    println(data.getClass())
                                data.each { k, v ->
                                    v.each {
                                        it.each{ keys, values ->
                                            if (keys.equals(PW_REPOSITORY.trim())){
                                                CURRENT_COMMIT_HASH = values
                                                println "OLD_COMMIT_HASH: $CURRENT_COMMIT_HASH"
                                            }
                                        }
                                    }
                                }
                                dir("../${PW_REPOSITORY}"){
                                    try {
                                        currentTimestamp = sh(returnStdout: true, script: "git show -s --format=%ct ${CURRENT_COMMIT_HASH}").trim()
                                    }
                                    catch(Exception ex) {
                                        println "This commit ID was not found in this repository: ${PW_REPOSITORY}, and on this branch: ${dst_branch}"
                                        currentBuild.result = 'FAILURE'
                                        notifyFailure()
                                        throw ex
                                    }
                                    newTimestamp = sh(returnStdout: true, script: "git show -s --format=%ct ${NEW_COMMIT_HASH}").trim()
                                }
                                if (currentTimestamp < newTimestamp) {
                                    sh(returnStatus: true, script: "sed -e 's/\"${PW_REPOSITORY}\": \".*\"/\"${PW_REPOSITORY}\": \"${NEW_COMMIT_HASH}\"/' --in-place manifest.json")
                                } else {
                                    println "Warning: a latest commit hash time is already updated..."
                                    return
                                }
								
								retValue = sh(returnStatus: true, script: "git config user.name")
                                if (retValue != 0) {
									println "git user.name is not configured. configuring now"
									sh """
									git config user.name "pw-build"
									"""
								}
								retValue = sh(returnStatus: true, script: "git config user.email")
                                if (retValue != 0) {
									println "git user.email is not configured. configuring now"
									sh """
									git config user.email "pw-build@parallelwireless.com"
									"""
								}
								
                                retValue = sh(returnStatus: true, script: "git commit -m '${env.GIT_COMMIT_MSG}' manifest.json")
                                if (retValue != 0){
                                    println retValue
                                    println "Warning: nothing to commit..."
                                    currentBuild.result = 'SUCCESS'
                                    return
                                }
								
                                retValue = sh(returnStatus: true, script: "git push --set-upstream -f origin ${INTEG_BRANCH}")
                                if (retValue != 0){
                                    println retValue
                                    println "Warning: Push failed - one or more git commands failed..."
                                    currentBuild.result = 'FAILURE'
                                    notifyFailure()
                                    return
                                }
                                pull_req = sh( returnStdout : true, script: "sh ../global-packaging/PullReqfile.sh ${INTEG_BRANCH} ${dst_branch} ${pull_api} ${remote} ${remote} ${buildUser} '${GIT_COMMIT_MSG}'").trim()
                                println pull_req
            
                                def props = readJSON text:pull_req.toString(),returnPojo: true

                                if ( props['errors'] != null ){
                                   println props.errors[0].existingPullRequest.links.self[0].href
                                   def ID = props.errors[0].existingPullRequest.id
                                   def VERSION = props.errors[0].existingPullRequest.version
                                   pull_api = sh(returnStdout : true, script: "echo ${pull_api}/${ID}").trim()
                                   pull_req = sh(returnStdout : true, script: "sh ../global-packaging/PullReqUpdate.sh ${INTEG_BRANCH} ${pull_api} ${buildUser} '${GIT_COMMIT_MSG}' ${ID} ${VERSION}").trim()
                                   println pull_req
                                   pull_list.add(props.errors[0].existingPullRequest.links.self[0].href)
                                } else { println props.links.self[0].href
                                   pull_list.add(props.links.self[0].href)
                                }
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
            notifyFailure()
            throw Error
        }
        finally {
            cleanWs()
            notifyBitbucket(commitSha1:"$NEW_COMMIT_HASH")
        }
    }
  }
 }
}

def notifyFailure() {
     emailext (
         mimeType: 'text/html',
         to: "${env.AUTHOR_EMAIL} , cc:Access-DevOps@parallelwireless.com",
         subject: "[${currentBuild.result}] - ${env.JOB_NAME} - Build #${BUILD_NUMBER}",
         body: "<b>Upstream Repository:</b> ${repository_slug}<br> \
                <b>Upstream Branch:</b> ${push_changes_0_new_name}<br> \
                <b>Upstream Sha1:</b> ${push_changes_0_new_target_hash}<br> \
                <b>Build URL:</b> ${env.BUILD_URL}<br>"
    )
}

@NonCPS
def getBuildUser() {
    if (currentBuild.rawBuild.getCause(Cause.UserIdCause) != null) {
        return currentBuild.rawBuild.getCause(Cause.UserIdCause).getUserId()
    } else{
        return 'parallel'
    }
}
def getUpstreamJob() {
    if (currentBuild.rawBuild.getCause(Cause.UpstreamCause) != null){ 
        if (currentBuild.rawBuild.getCause(Cause.UpstreamCause).toString().contains('core-access')){
            return "access-product-packaging"
        } else if (currentBuild.rawBuild.getCause(Cause.UpstreamCause).toString().contains('hng-pipeline')){
            return "integrated-packaging"
        } else {
            println "Job started by upstream"
        }    
    } else {
        println "Job not started by upstream"
    }
}
