#!/usr/bin/env bash

integ_branch=$1
feat_branch=$2

echo $integ_branch
echo $feat_branch
 
process_id=`cat /dev/urandom | tr -dc '0-9' | fold -w 256 | head -n 1 | sed -e 's/^0*//' | head --bytes 10`
cat > /tmp/${process_id}_datareq.json <<EOF

  {
    "title": "HNG-SYNC-PIPELINE",
    "description": "Pull Requested has been created using HNG-SYNC-PIPELINE from $integ_branch to $feat_branch",
    "state": "OPEN",
    "open": true,
    "closed": false,
    "fromRef": {
        "id": "sourcepullbranch",
        "repository": {
            "slug": "core",
            "name": null,
            "project": {
                "key": "CD"
             }
         }
    },
    "toRef": {
        "id": "refs/heads/$feat_branch",
        "repository": {
            "slug": "core",
            "name": null,
            "project": {
                "key": "CD"
            }
        }
    },
    "locked": false,
    "links": {
        "self": [
            null
        ]
    }
  }

EOF

#cp datreq.json datareq.json
modified_branch=`echo "$integ_branch"|sed -e "s/\//%/g"`

sed -i "s/sourcepullbranch/$modified_branch/g" /tmp/${process_id}_datareq.json
sed -i "s/%/\//g" /tmp/${process_id}_datareq.json

curl -s -u pw-build:builtit4u! -H "Content-Type: application/json" https://git.parallelwireless.net/rest/api/1.0/projects/CD/repos/core/pull-requests -X POST --data @/tmp/${process_id}_datareq.json >/tmp/${process_id}_curl.log 2>&1


echo "Pull request created: "
