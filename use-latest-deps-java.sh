#!/usr/bin/env bash

# Copyright 2016 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

print_usage () {
  (>&2 echo "Usage:")
  (>&2 echo "    $0 [-d] github-user/repository-name")
  (>&2 echo "Arguments:")
  (>&2 echo "    -d: do a dry-run. Don't push or send a PR.")
}

# Check for optional arguments.
DRYRUN=0
while getopts :d opt; do
  case $opt in
    d)
      (>&2 echo "Entered dry-run mode.")
      DRYRUN=1
      ;;
    \?)
      (>&2 echo "Got invalid option -$OPTARG.")
      print_usage
      exit 1
      ;;
  esac
done
shift $((OPTIND-1))


# Check that positional arguments are set.
if [[ -z $1 ]] ; then
  (>&2 echo "Missing repo argument.")
  print_usage
  exit 1
fi
if [[ "$1" != *"/"* ]] ; then
  (>&2 echo "Repo argument needs to be of form username/repo-name.")
  print_usage
  exit 1
fi
REPO=$1


# Get this script's directory.
# http://stackoverflow.com/a/246128/101923
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

set -x

# Update dependencies and plugins that use properties for version numbers.
RULES_URI="file://$DIR/java-repo-tools/versions-rules.xml"
mvn versions:use-latest-releases "-Dmaven.version.rules=$RULES_URI"
mvn versions:update-properties "-Dmaven.version.rules=$RULES_URI"


# If there were any changes, test them and then push and send a PR.
git diff --quiet
if [[ "$?" -ne 0 ]] ; then
  if [[ -e travis.sh ]] ; then
    ./travis.sh
  else
    mvn --batch-mode clean verify
  fi

  if [[ "$?" -ne 0 ]] ; then
    (>&2 echo "Tests failed! Not sending PR.")
    exit 1
  fi

  if [[ "$DRYRUN" -eq 0 ]] ; then
    "${DIR}/commit-and-push.sh"
    "${DIR}/send-pr.sh" "$REPO"
  fi
fi
