#!/bin/bash -e

. aws.conf

export LOCAL_BROKER_URL
rm -rf build
mkdir build

function copy_files()
{
	local src="$1"
	local dst="$2"
	cp -ra $src $dst
	cp -ra lib $dst
	cp COPYRIGHT LICENSE $dst
}

function process_templates()
{
	local dir="$1"
	pushd $dir >/dev/null
	
	find -type f -name '*.erb' | while read tpl; do
		echo "   - $tpl -> ${tpl%.erb}"
		erb "$tpl" > ${tpl%.erb}
		rm -f "$tpl"
	done
	popd >/dev/null
	chmod +x build/*/bin/*
}

function build_s3_cartridges()
{
	for ((i=0; i < ${#AWS_REGION_NAME[*]}; i++)); do
		export REGION_NAME=${AWS_REGION_NAME[$i]}
		export REGION_SHORT_NAME=${AWS_REGION_SHORT_NAME[$i]}
		export REGION_DISPLAY_NAME=${AWS_REGION_DISPLAY_NAME[$i]}
		cart=openshift-aws-s3-$REGION_NAME
		echo " - $cart"

		copy_files openshift-aws-s3 build/$cart
		process_templates build/$cart
		mv build/$cart/openshift-origin-cartridge-aws-s3.spec build/$cart/openshift-origin-cartridge-aws-s3-$REGION_NAME.spec
		vim build/$cart/openshift-origin-cartridge-aws-s3-$REGION_NAME.spec

		unset REGION_NAME
		unset REGION_SHORT_NAME
		unset REGION_DISPLAY_NAME
	done
}

function build_account_cartridge()
{
	cart=openshift-aws-account
	echo " - $cart"

	copy_files $cart build/$cart
	process_templates build/$cart
	vim build/$cart/openshift-origin-cartridge-aws-account.spec
}

function commit()
{
	if [ $(git status --porcelain |wc -l) -gt 0 ]; then
		echo 'Commiting changes...'
		git add build
		git commit -a -m 'Build'
	fi
}

build_account_cartridge
build_s3_cartridges
commit

if [ "$1" == '--rpm' ]; then
	shift
	./build-rpm.sh $@
fi
