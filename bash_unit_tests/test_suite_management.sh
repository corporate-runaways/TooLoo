#!/usr/bin/env sh

setup_suite() {

	XDG_DATA_HOME=$(pwd)"/bash_unit_tests/TEST_XDG_DATA_HOME";
	echo ""
	echo "XDG_DATA_HOME: $XDG_DATA_HOME"
	rm -rf $XDG_DATA_HOME 2>&1 > /dev/null
	mkdir -p $XDG_DATA_HOME
	TEST_DATA_DIR=$(pwd)"/bash_unit_tests/test_data"
	DB_LOCATION=$XDG_DATA_HOME"/clu/database.db"

}

teardown_suite() {
	#rm -rf $XDG_DATA_HOME
	echo "DONE";
}
