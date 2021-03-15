#!/usr/bin/env bash

# To update an existing PR 5 values are a needed.
# Using method PUT
# id, version, title, description, reviewers.

integ_branch=$1
pull_url=$2
pr_user=$3
commit_msg=$4
id=$5
version=$6

process_id=`echo $RANDOM`
cat > /tmp/${process_id}_datareq.json <<EOF

  {
    "id": "$id",
    "version": "$version",
    "title": "commitmessage",
    "description": "Automatic PR created from $integ_branch by $pr_user",
    "reviewers": [
      {
        "user": {
            "name": "pw-build"
         }
      }
     ]
  }

EOF

modified_commit_message=`echo "$commit_msg"|sed -e "s/\//%/g"`
sed -i "s/commitmessage/$modified_commit_message/g" /tmp/${process_id}_datareq.json
sed -i "s/%/\//g" /tmp/${process_id}_datareq.json

curl -s -u ${prUser}:${prPass} -H "Content-Type: application/json" $pull_url -X PUT --data @/tmp/${process_id}_datareq.json
#> /tmp/${process_id}_curl.log 2>&1
