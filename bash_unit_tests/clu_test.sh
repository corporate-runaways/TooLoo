#!/usr/bin/env sh

source ./test_suite_management.sh

if [ ! -e clu ]; then
	cd ../
	if [ ! -e clu ]; then
		echo "Run me from within the bash_unit_tests directory"
		exit 1
	fi
fi




test_1_hyphen_v () {
  #assert_equals expected actual message
  clu_hyphen_v=$(raku -I lib clu -v 2>&1 | head -n2 | tail -n1)
  assert_equals "$clu_hyphen_v" "  clu -V|--version[=Any] [--verbose[=Any]]" \
	  "should provide usage for clu -v"

  assert_status_code 2 `raku -I lib clu -v > /dev/null 2>&1`
}

test_2_hyphen_hyphen_version () {
  clu_hyphen_v=$(raku -I lib clu --version 2>&1 | sed -e "s/ running.*//")
  assert_equals "$clu_hyphen_v" "clu - provided by  ," \
	  "should provide usage for clu --version"

  assert_status_code 2 `raku -I lib clu --version > /dev/null 2>&1`
}

test_3_add_new() {
	file_path=$TEST_DATA_DIR"/raku_test_no_demo.meta.toml"
	add_new_output=$(raku -I lib clu add $file_path | sed -e "s/ \/.*//")
	assert_equals "$add_new_output" "Successfully ingested"
}
