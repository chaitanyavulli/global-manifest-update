#!/usr/bin/env bash

integ_branch=$1
feat_branch=$2
pull_url=$3
src_slug=$4
dst_slug=$5
pr_user=$6
commit_msg=$7

process_id=`cat /dev/urandom | tr -dc '0-9' | fold -w 256 | head -n 1 | sed -e 's/^0*//' | head --bytes 10`
cat > /tmp/${process_id}_datareq.json <<EOF

  {
    "title": "Automatic PR created from $integ_branch by $pr_user",
    "description": "commitmessage",
    "state": "OPEN",
    "open": true,
    "closed": false,
    "fromRef": {
        "id": "sourcepullbranch",
        "repository": {
            "slug": "$src_slug",
            "name": null,
            "project": {
                "key": "CD"
             }
         }
    },
    "toRef": {
        "id": "destpullbranch",
        "repository": {
            "slug": "$dst_slug",
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
modified_dest_branch=`echo "$feat_branch"|sed -e "s/\//%/g"`
modified_commit_message=`echo "$commit_msg"|sed -e "s/\//%/g"`
sed -i "s/sourcepullbranch/$modified_branch/g" /tmp/${process_id}_datareq.json
sed -i "s/destpullbranch/$modified_dest_branch/g" /tmp/${process_id}_datareq.json
sed -i "s/commitmessage/$modified_commit_message/g" /tmp/${process_id}_datareq.json
sed -i "s/%/\//g" /tmp/${process_id}_datareq.json

curl -s -u ${prUser}:${prPass} -H "Content-Type: application/json" $pull_url -X POST --data @/tmp/${process_id}_datareq.json 
#> /tmp/${process_id}_curl.log 2>&1
