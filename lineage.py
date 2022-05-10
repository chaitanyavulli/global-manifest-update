#
# Copyright (c) 2014-2022 Parallel Wireless, Inc. All rights reserved.
#

import json
import sys
import os
import shutil
import subprocess as sp

HASH = os.getenv('push_changes_0_new_target_hash')
SHORT_HASH = HASH[:8]
LONG_TABLE = 20
SHORT_TABLE = 10
REPO = os.getenv('repository_slug')
if len(HASH) != 40:
    print('ERROR: expecting 40 chars... Failing...')
    sys.exit(1)
git_url="ssh://git@git.parallelwireless.net:7999"
bitbucket_main="https://git.parallelwireless.net/projects/"

BRANCH = os.getenv('push_changes_0_new_name')
if BRANCH == 'develop':
    branch_order = ['origin/develop*','origin/release*','origin/feature*','origin/integ*','origin/private*','origin/bugfix*']
else:
    branch_order = ['origin/release*','origin/develop*','origin/feature*','origin/integ*','origin/private*','origin/bugfix*']

packaging_lsts = []
repos_together_lsts = [] # to sort according to date

pipe = sp.Popen(["cd ../"+REPO+" ; git log -1 --pretty=format:%s"], shell=True , stdout=sp.PIPE, stderr=sp.PIPE)
main_commit = pipe.communicate()
print main_commit[0]

def clone(repository,sha1):
    repo_lsts = []
    print '\nLooking for commits from '+repository,sha1
    if repository == "bbpms_bsp":
        project="bsp"
    elif repository == "access-iso":
        project="pwis"
    elif repository == "rt-monitoring":
        project="da"
    elif repository == "uniperf":
        project="tool"
    elif repository == "near_rtric":
        project="NEAR"
    else:
        project="cd"

    if repository == "nrtric":
        repository = "cloudapps"
        
    if os.path.exists(repository):
        print "Warning: Repository path exists... deleting..."
        shutil.rmtree(repository)

    os.mkdir(repository)
    os.chdir(repository)
    pipe = sp.Popen(["GIT_LFS_SKIP_SMUDGE=1 git init"], shell=True , stdout=sp.PIPE, stderr=sp.PIPE)
    res = pipe.communicate() # ('Initialized empty Git repository in /home/vbuslovich/source/test/test4/.git/\n', '')

    #pipe = sp.Popen(["git remote add origin "+git_url+"/"+project+"/"+repository+"; git fetch -n --depth "+str(clone_depth)+" origin "+sha1], shell=True , stdout=sp.PIPE, stderr=sp.PIPE)
    pipe = sp.Popen(["git remote add origin "+git_url+"/"+project+"/"+repository+"; git fetch --all --no-tags"], shell=True , stdout=sp.PIPE, stderr=sp.PIPE)
    res = pipe.communicate() # ('', 'From ssh://git.parallelwireless.net:7999/cd/cws-rrh\n * branch            382d11aefe6ef77a7747fb8f7a4df36bc7b110a9 -> FETCH_HEAD\n')

    #pipe = sp.Popen(["GIT_LFS_SKIP_SMUDGE=1 git checkout FETCH_HEAD"], shell=True , stdout=sp.PIPE, stderr=sp.PIPE)
    pipe = sp.Popen(["GIT_LFS_SKIP_SMUDGE=1 git reset --hard "+sha1], shell=True , stdout=sp.PIPE, stderr=sp.PIPE)
    res = pipe.communicate() # ('', "Note: checking out 'FETCH_HEAD'.\n\nYou are in 'detached HEAD' state. You can look around, make experimental\nchanges and commit them, and you can discard any commits you make in this\nstate without impacting any branches by performing another checkout.\n\nIf you want to create a new branch to retain commits you create, you may\ndo so (now or later) by using -b with the checkout command again. Example:\n\n  git checkout -b <new-branch-name>\n\nHEAD is now at 382d11a... BTSDEV-1855: Update the timeout for the OpenStack VM creation\n")

    pipe = sp.Popen(["git log -1 --pretty=format:%s"], shell=True , stdout=sp.PIPE, stderr=sp.PIPE)
    commit = pipe.communicate()
    commit = commit[0]
    print commit
    
    test=commit.split(':')
    for t in test:
        if t in main_commit[0]:
            print 'found commit - to bold'
            commit='<b>'+commit+'</b>'
            break

    pipe = sp.Popen(["TZ=UTC git log -1 --format=%cd --date=iso-local"], shell=True , stdout=sp.PIPE, stderr=sp.PIPE)
    date = pipe.communicate()
    print date[0]

    pipe = sp.Popen(["git log -1 --pretty=format:%an"], shell=True , stdout=sp.PIPE, stderr=sp.PIPE)
    author = pipe.communicate()
    print author[0]
    
    for b in branch_order:
        pipe = sp.Popen(["git branch -r --list "+b+" --contains "+sha1+" --sort=-committerdate | tail -1"], shell=True , stdout=sp.PIPE, stderr=sp.PIPE)
        branch = pipe.communicate()
        print branch
        if branch[0] != '':
            print branch[0]
            break
    if branch[0] == '':
        pipe = sp.Popen(["git branch -r --contains "+sha1+" --sort=-committerdate"], shell=True , stdout=sp.PIPE, stderr=sp.PIPE)
        branch = pipe.communicate()
        print branch[0]
    
    bitbucket_link=bitbucket_main+project+"/repos/"+repository+"/commits/"+sha1
    artifactory_link="https://pwartifactory.parallelwireless.net/ui/artifactSearchResults?artifactsSearchType=Property&propertiesSetsObject%5BcommitID%5D="+sha1+"&repositories%5B0%5D=pw-products&type=artifacts"

    packaging_lsts.append([repository,commit,branch[0],date[0],author[0],sha1,bitbucket_link,artifactory_link])

    for i in range(0,LONG_TABLE):
        pipe = sp.Popen(["TZ=UTC git log -n 1 --skip "+str(i)+" --pretty=format:'%s|-|%cd|-|%an|-|%H' --merges --date=iso-local"], shell=True , stdout=sp.PIPE, stderr=sp.PIPE)
        res = pipe.communicate()
        print res[0]
        if res[0] != '':
            bitbucket_link=bitbucket_main+project+"/repos/"+repository+"/commits/"+res[0].split('|-|')[3]
            artifactory_link="https://pwartifactory.parallelwireless.net/ui/artifactSearchResults?artifactsSearchType=Property&propertiesSetsObject%5BcommitID%5D="+res[0].split('|-|')[3]+"&repositories%5B0%5D=pw-products&type=artifacts"
            repo_lsts.append([res[0].split('|-|') , bitbucket_link , artifactory_link])
            repos_together_lsts.append([repository] + res[0].split('|-|') + [bitbucket_link] + [artifactory_link])
    del repo_lsts[SHORT_TABLE:]
    create_sec_html(repo_lsts,repository)

def create_main_html(packaging_lsts):
    strTable = """<html><p><b>"""+REPO+""" - """+HASH+"""<br> Last change is: """+main_commit[0]+"""</b></p><table border="1"><tr><th>Repository</th><th>Commit</th><th>Branch</th><th>Date</th><th>Author</th><th>sha1</th><th>Bitbucket</th><th>Artifactory</th></tr>"""
    for lst in packaging_lsts:
        strRW = "<tr><td>"+str(lst[0])+ "</td><td style='max-width: 500px;'>"+str(lst[1])+"</td><td>"+str(lst[2])+"</td><td>"+str(lst[3])+"</td><td>"+str(lst[4])+"</td><td>"+str(lst[5])+"</td><td><a href="+str(lst[6])+">Link</a></td><td><a href="+str(lst[7])+">Link</a></td></tr>"
        strTable = strTable+strRW
    strTable = strTable+"</table><br><br><br></html>"
    with open("package_lineage.html", 'a') as outfile:
        outfile.write(strTable)

def create_sec_html(repo_lsts,repository):
    os.chdir('..')
    strTable = """<html><p><b>"""+repository+"""</b></p><table border="1"><tr><th>Commit</th><th>Date</th><th>Author</th><th>sha1</th><th>Bitbucket</th><th>Artifactory</th></tr>"""
    for lst in repo_lsts:
        strRW = "<tr><td style='max-width: 500px;'>"+str(lst[0][0])+ "</td><td>"+str(lst[0][1])+"</td><td>"+str(lst[0][2])+"</td><td>"+str(lst[0][3])+"</td><td><a href="+str(lst[1])+">Link</a></td><td><a href="+str(lst[2])+">Link</a></td></tr>"
        strTable = strTable+strRW
    strTable = strTable+"</table><br><br><br></html>"
    with open("repo_lineage.html", 'a') as outfile:
        outfile.write(strTable)

def create_date_html(repos_together_lsts):
    repos_together_lsts = sorted(repos_together_lsts, key = lambda x: x[2] , reverse=True)
    del repos_together_lsts[LONG_TABLE:]
    strTable = """<html><p><b>Last """+str(LONG_TABLE)+""" commits of the upstream components, sorted in a chorological order.</b></p><table border="1"><tr><th>Repository</th><th>Commit</th><th>Date</th><th>Author</th><th>sha1</th><th>Bitbucket</th><th>Artifactory</th></tr>"""
    for lst in repos_together_lsts:
        strRW = "<tr><td style='max-width: 500px;'>"+str(lst[0])+ "</td><td>"+str(lst[1])+"</td><td>"+str(lst[2])+"</td><td>"+str(lst[3])+"</td><td>"+str(lst[4])+"</td><td><a href="+str(lst[5])+">Link</a></td><td><a href="+str(lst[6])+">Link</a></td></tr>"
        strTable = strTable+strRW
    strTable = strTable+"</table><br><br><br></html>"
    with open("date_lineage.html", 'a') as outfile:
        outfile.write(strTable)

def merge_html(file1,file2,file3):
    print "Merging 3 html files..."
    with open("release_notes_"+SHORT_HASH+".html" , 'w') as outfile:
        for fname in [file1,file2,file3]:
            with open(fname) as infile:
                outfile.write(infile.read())

def get_string_with_properties():
    argCount =  len(sys.argv)
    fileName=''
    property=''
    if argCount > 1:
        fileName = str(sys.argv[1])
        try:
            with open(fileName, 'r') as json_file:
                prod_dict = json.load(json_file)
                print(json.dumps(prod_dict, indent=2))
                # Since this is a nested Dictionary
                # Read the first item
                for prod_key, prod_val in prod_dict.items():
                    for repo_list in prod_val:
                        for repo_key, repo_val in repo_list.items():
                            x = clone(repo_key,repo_val)
        except (IOError, OSError) as err:
            print("OS error:{0}".format(err))
    else:
        print("Manifest file is not passed as argument")
if __name__ == '__main__':
    #clone('access-product-packaging',HASH)
    get_string_with_properties()
    create_main_html(packaging_lsts)
    create_date_html(repos_together_lsts)
    merge_html("package_lineage.html","date_lineage.html","repo_lineage.html")
