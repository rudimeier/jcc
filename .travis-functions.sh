#!/bin/bash

#
# .travis-functions.sh:
#   - helper functions to be sourced from .travis.yml
#   - designed to respect travis' environment but testing locally is possible
#

if [ ! -f ".travis.yml" ]; then
	echo ".travis-functions.sh must be sourced from source dir" >&2
	return 1 || exit 1
fi

function travis_show_env
{
	# don't show secret "travis secure variables"
	env | grep -v "SECRET_" | LC_ALL=C sort
}

function travis_have_sudo
{
	HAVE_SUDO="no"
	if test "$(sudo id -ru)" = "0"; then
		HAVE_SUDO="yes"
	fi
	echo "HAVE_SUDO=$HAVE_SUDO"
}

function travis_jdk_switcher
{
	# There is no jdk_switcher on travis OSX images :(
	if test "$TRAVIS_OS_NAME" != "osx"; then
		jdk_switcher use "$TESTJDK"
	else
		export JAVA_HOME=$(/usr/libexec/java_home)
	fi
}

function install_deps_osx
{
	brew update >/dev/null

	if [ "$OSX_PY" = "3" ]; then
		brew install python3 || return
		mkdir ~/bin || return
		ln -s $(which python3) $HOME/bin/python || return
		ln -s $(which pip3) $HOME/bin/pip || return
		hash -r
	fi
}

function install_deps_linux
{
	true
}


function travis_install_script
{
	if [ "$TRAVIS_OS_NAME" = "osx" ]; then
		install_deps_osx || return
	else
		install_deps_linux || return
	fi

	# on old python we need probably newer setuptools
	if python --version 2>&1| grep -q "\b2\."; then
		pip install --upgrade setuptools || return
	fi
}

function travis_build_java
{
	true
}

function travis_build_python
{
	echo "######## begin version info ########"
	python --version
	java -version
	javac -version
	echo "$JAVA_HOME"
	echo "$JAVA_BINDIR"
	echo "$JAVA_ROOT"
	echo "######## end version info   ########"

	# build jcc
	JCC_JDK="$JAVA_HOME" python setup.py install || return

	# build test jar
	pushd test
	javac HelloWorld.java
	jar -cf hello.jar HelloWorld.class
	popd

	# build test package hellojcc
	curdir=$(pwd)
	rm -rf /tmp/clear
	mkdir -p /tmp/clear
	pushd /tmp/clear

	python --version
	python -m jcc --jar "$curdir/test/hello.jar" \
	       --python hellojcc \
	       --version 1.2.3 \
	       --build \
	       --maxheap 1024M \
	       --install \
	       || return

	# run hellojcc
	python <<-'EOF'
		from __future__ import print_function
		import hellojcc as X
		import hellojcc._hellojcc as Y
		X.initVM()
		print("classpath:", X.CLASSPATH)
		print("JArray works:", Y.JArray("byte")("JArray works"))
		X.HelloWorld().main("bla")
	EOF

	popd
}

function travis_build
{
	travis_build_java || return
	travis_build_python || return
}

function travis_script
{
	local ret
	set -o xtrace

	travis_build
	ret=$?

	set +o xtrace
	return $ret
}
