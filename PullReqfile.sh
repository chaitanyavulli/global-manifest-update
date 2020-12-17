#!/usr/bin/env bash

integ_branch=$1
feat_branch=$2
pull_url=$3

echo $integ_branch
echo $feat_branch
echo $pull_url
echo $src_slug
echo $dst_slug

process_id=`cat /dev/urandom | tr -dc '0-9' | fold -w 256 | head -n 1 | sed -e 's/^0*//' | head --bytes 10`
cat > /tmp/${process_id}_datareq.json <<EOF

  {
    "title": "Pull Request",
    "description": "Pull Requested has been created from $integ_branch to $feat_branch",
    "state": "OPEN",
    "open": true,
    "closed": false,
    "fromRef": {
        "id": "sourcepullbranch",
        "repository": {
            "slug": $src_slug,
            "name": null,
            "project": {
                "key": "CD"
             }
         }
    },
    "toRef": {
        "id": $feat_branch",
        "repository": {
            "slug": $dst_slug,
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

curl -s -u pw-build:builtit4u! -H "Content-Type: application/json" $pull_url -X POST --data @/tmp/${process_id}_datareq.json >/tmp/${process_id}_curl.log 2>&1


echo "Pull request created: "
