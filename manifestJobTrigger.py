import json
import time
import jenkins
import requests
from requests.auth import HTTPBasicAuth


class PWJenkins:
    def __init__(self, url):
        self.url = url
        self.connect_timeout = 600
        self.server = None

    def connect(self, username, password):
        if self.server == None:
            self.server = jenkins.Jenkins(self.url, username=username, password=password)
            print('Logging in to Jenkins')
        else:
            print('Already logged in to Jenkins')
        user = self.server.get_whoami()
        version = self.server.get_version()
        print('Connected to Jenkins v%s as USER: %s' % (version, user['fullName']))
    
    def trigger_build(self, job_name, paramters):
        job_id = self.server.build_job(job_name, parameters=paramters)
        print('Triggered Job Queue #%s'% (job_id))


class BitBucket:
    def __init__(self):
        self.repo_commit_links = {
            'core': 'https://git.parallelwireless.net/rest/api/1.0/projects/CD/repos/core/commits',
            'pwconfig': 'https://git.parallelwireless.net/rest/api/1.0/projects/CD/repos/pwconfig/commits'                
        }
    
    def get_latest_commit(self, repo_name, branch_name, username, password):
        branch_filter = '?until=refs/heads/' + branch_name + '&merges=include'
        commits_url = self.repo_commit_links[repo_name] + branch_filter
        r = requests.get(url=commits_url, auth = HTTPBasicAuth(username, password))
        data = r.json()
        if data['values'][0]['id']:
            latest_commit = data['values'][0]['id']
            print("repo: %s  branch: %s  latest-commit-id: %s"% (repo_name, branch_name, latest_commit))
            return latest_commit
        else:
            print("Error getting latest commit")
            return None

repo_list = ['pwconfig', 'core']
branch_name = 'develop'
creds_file = './triggerCreds.json'
creds = {}

with open(creds_file) as f:
    creds = json.load(f)

server = PWJenkins('https://pwjenkins.parallelwireless.net:8443')
server.connect(creds['jenkins']['username'], creds['jenkins']['token'])

job_name = 'global-manifest-update'
delay = 2.0

bitbucket_handler = BitBucket()

for repo_name in repo_list:
    job_params = {
        'push_changes_0_new_name': None,
        'repository_slug': None,
        'push_changes_0_new_target_hash': None,
        'global_packaging_branch': None
    }
    print("Getting latest Commit for Repo: %s Branch: %s" % (repo_name, branch_name))
    latest_commit = bitbucket_handler.get_latest_commit(repo_name, branch_name, creds['bitbucket']['username'], creds['bitbucket']['token'])

    job_params['push_changes_0_new_name'] = branch_name
    job_params['repository_slug'] = repo_name
    job_params['push_changes_0_new_target_hash'] = latest_commit
    job_params['global_packaging_branch'] = 'develop'

    print("waiting %s sec" % (delay))
    time.sleep(delay)
    print("Triggering Job: %s with params: %s" %(job_name, job_params))
    server.trigger_build(job_name,job_params)
    print("Success\n")
