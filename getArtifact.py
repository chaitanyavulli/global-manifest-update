#!/usr/bin/python
import requests
import sys
import re

latest = (-1, -1)
tokenUriMap = {}

def getArtifactByDate(date, branch):
    #print("cmd is : curl -s https://pwartifactory.parallelwireless.net/artifactory/api/search/prop?commit-date=%s&branch=%s&HNG-DEV-CI=successful&type=image"
    #                    %(date,branch))
    return requests.get("https://pwartifactory.parallelwireless.net/artifactory/api/search/prop?commit-date=%s&branch=%s&HNG-DEV-CI=successful&HNG-QA-CI=successful&type=image"
                        %(date, branch))

def getArtifactByCommit(commit, branch):
    return requests.get("https://pwartifactory.parallelwireless.net/artifactory/api/search/prop?commitID=%s&branch=%s&type=image"
                        %(commit, branch))

def print_error():
    msg = "\n".join(["Invalid commands", "Pls add parametes as given below",
                     "./getHNGURI.py date branch", "date in the format YYYYMMDD",
                     "Branch: branch to check in string format",
                     "e,g. ./getHNGURI.py 20200907 private/hng_qa_ci_stability_dummy_branch", ""])
    print(msg)

def getDateToken(result):
    return re.findall("[0-9]{8}\.[0-9]{3,6}",result)[0].split(".")

def checkAndMapURI(results):
    global latest
    global tokenUriMap

    if not results:
        return
    resultList = results["results"]
    for result in resultList:
        uri = result["uri"]
        try:
            date,token = getDateToken(uri)
            tokenTuple = (int(date),int(token))
        except:
            pass
        else:
            if tokenTuple > latest:
                latest = tokenTuple
            tokenUriMap[tokenTuple] = uri

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print_error()
        sys.exit()
    #results = getArtifactByDate(sys.argv[1],sys.argv[2])
    results = getArtifactByCommit(sys.argv[1],sys.argv[2])
    checkAndMapURI(results.json())
    if latest is not None:
        print("Build found: " + tokenUriMap[latest])
        sys.exit(0)
    else:
        print("Build not found")
        sys.exit(1)

