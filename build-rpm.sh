#!/bin/bash

set -eu

branch=master
rpm_dir=~/openshift-aws-rpms/$branch
update_repo=1
build=1
publish=0
while [ $# -gt 0 ]; do
	case "$1" in
		--no-update-repo) update_repo=0;;
		--no-build) build=0;;
		--no-publish) publish=0;;
		--branch) shift; branch="$1";;
		*) echo "invalid param: $1"
		   echo "use: $0 [--no-build] [--no-publish] [--branch BRANCH]"
		   exit 1
	esac
	shift
done

if [ $publish -eq 1 ]; then
	if [ -z "$AWS_ACCESS_KEY_ID" -o -z "$AWS_SECRET_ACCESS_KEY" ]; then
		echo Missing AWS credentials
		exit 1
	fi
fi

set -x

_build()
{
	pushd $1
	tito tag --keep-version
	git push --tags
	tito build --debug --rpm --scl=ruby193
	popd
}

if [ $build -eq 1 ]; then
	rm -rf /tmp/tito
	mkdir -p /tmp/tito

	if [ $update_repo -eq 1 ]; then
		git checkout "$branch"
		git pull origin "$branch"
	fi
	_build build/openshift-aws-account
	_build build/openshift-aws-s3-sa-east-1
	_build build/openshift-aws-s3-us-west-2

	mkdir -p $rpm_dir/noarch/
	cp -v /tmp/tito/noarch/*.rpm $rpm_dir/noarch/
fi

if [ $publish -eq 1 ]; then
	if [ -z "$AWS_ACCESS_KEY_ID" -o -z "$AWS_SECRET_ACCESS_KEY" ]; then
	fi

	cd ${rpm_dir}
	createrepo .

	aws s3 rm "s3://getup-mirror/$branch/repodata" --recursive
	aws s3 sync . "s3://getup-mirror/$branch" --region us-west-2 --acl public-read
fi
