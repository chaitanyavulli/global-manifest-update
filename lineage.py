#
# Copyright (c) 2014-2021 Parallel Wireless, Inc. All rights reserved.
#

import json
import sys
import os
import subprocess as sp

HASH = os.getenv('push_changes_0_new_target_hash')
REPO = os.getenv('repository_slug')
if len(HASH) != 40:
    print('ERROR: expecting 40 chars... Failing...')
    sys.exit(1)
git_url="ssh://git@git.parallelwireless.net:7999"
#clone_depth=os.getenv('clone_depth')
clone_depth='50'

packaging_lsts = []

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
    else:
        project="cd"

    if repository == "nrtric":
        repository = "cloudapps"
        

    os.mkdir(repository)
    os.chdir(repository)
    pipe = sp.Popen(["git init"], shell=True , stdout=sp.PIPE, stderr=sp.PIPE)
    res = pipe.communicate() # ('Initialized empty Git repository in /home/vbuslovich/source/test/test4/.git/\n', '')

    pipe = sp.Popen(["git remote add origin "+git_url+"/"+project+"/"+repository+"; git fetch -n --depth "+str(clone_depth)+" origin "+sha1], shell=True , stdout=sp.PIPE, stderr=sp.PIPE)
    #pipe = sp.Popen(["git remote add origin "+git_url+"/"+project+"/"+repository+"; git fetch --all --no-tags"], shell=True , stdout=sp.PIPE, stderr=sp.PIPE)
    res = pipe.communicate() # ('', 'From ssh://git.parallelwireless.net:7999/cd/cws-rrh\n * branch            382d11aefe6ef77a7747fb8f7a4df36bc7b110a9 -> FETCH_HEAD\n')

    pipe = sp.Popen(["GIT_LFS_SKIP_SMUDGE=1 git checkout FETCH_HEAD"], shell=True , stdout=sp.PIPE, stderr=sp.PIPE)
    #pipe = sp.Popen(["git reset --hard "+sha1], shell=True , stdout=sp.PIPE, stderr=sp.PIPE)
    res = pipe.communicate() # ('', "Note: checking out 'FETCH_HEAD'.\n\nYou are in 'detached HEAD' state. You can look around, make experimental\nchanges and commit them, and you can discard any commits you make in this\nstate without impacting any branches by performing another checkout.\n\nIf you want to create a new branch to retain commits you create, you may\ndo so (now or later) by using -b with the checkout command again. Example:\n\n  git checkout -b <new-branch-name>\n\nHEAD is now at 382d11a... BTSDEV-1855: Update the timeout for the OpenStack VM creation\n")

    pipe = sp.Popen(["git log -1 --pretty=format:%s"], shell=True , stdout=sp.PIPE, stderr=sp.PIPE)
    res = pipe.communicate()
    print res[0]
    packaging_lsts.append([repository,res[0],sha1])
    pipe = sp.Popen(["git branch -r --contains "+sha1], shell=True , stdout=sp.PIPE, stderr=sp.PIPE)
    res = pipe.communicate()
    print res
    print ''
    for i in range(0,10):
        pipe = sp.Popen(["git log -n 1 --skip "+str(i)+" --pretty=format:'%s|-|%H' --merges"], shell=True , stdout=sp.PIPE, stderr=sp.PIPE)
        res = pipe.communicate()
        print res[0]
        repo_lsts.append([res[0].split('|-|')])
    create_sec_html(repo_lsts,repository)

def create_main_html(packaging_lsts):
    strTable = """<html><p><b>"""+REPO+"""</b></p><table border="1"><tr><th>Repository</th><th>Commit</th><th>sha1</th></tr>"""
    for lst in packaging_lsts:
        strRW = "<tr><td>"+str(lst[0])+ "</td><td>"+str(lst[1])+"</td><td>"+str(lst[2])+"</td></tr>"
        strTable = strTable+strRW
    strTable = strTable+"</table><br><br><br></html>"
    with open("package_lineage.html", 'a') as outfile:
        outfile.write(strTable)
    #hs = open("package_lineage.html", 'a')
    #hs.write(strTable)

def create_sec_html(repo_lsts,repository):
    os.chdir('..')
    strTable = """<html><p><b>"""+repository+"""</b></p><table border="1"><tr><th>Commit</th><th>sha1</th></tr>"""
    for lst in repo_lsts:
        strRW = "<tr><td>"+str(lst[0][0])+ "</td><td>"+str(lst[0][1])+"</td></tr>"
        strTable = strTable+strRW
    strTable = strTable+"</table><br><br><br></html>"
    with open("repo_lineage.html", 'a') as outfile:
        outfile.write(strTable)
    #hs = open("repo_lineage.html", 'a')
    #hs.write(strTable)

def merge_html(file1,file2):
    print "Merging 2 html files..."
    with open("lineage_"+HASH+".html" , 'w') as outfile:
        for fname in [file1,file2]:
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
    merge_html("package_lineage.html","repo_lineage.html")
