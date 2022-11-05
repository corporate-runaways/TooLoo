#!/usr/bin/env sh

setup_suite() {
	XDG_DATA_HOME=$(pwd)"/TEST_XDG_DATA_HOME";
	rm -rf $XDG_DATA_HOME 2>&1 > /dev/null
	mkdir -p $XDG_DATA_HOME

}

teardown_suite() {
	echo "DONE";
}
