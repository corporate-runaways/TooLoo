#!/usr/bin/env sh

source ./test_suite_management.sh

if [ ! -e tooloo ]; then
	cd ../
	if [ ! -e bin/tooloo ]; then
		echo "Run me from within the bash_unit_tests directory"
		exit 1
	fi
fi


TOOLOO_INVOCATION="raku -I lib bin/tooloo"

test_01_hyphen_v () {
  #assert_equals expected actual message
  tooloo_hyphen_v=$(XDG_DATA_HOME=$XDG_DATA_HOME $TOOLOO_INVOCATION -v 2>&1 | head -n2 | tail -n1)
  assert_equals "  bin/tooloo -V|--version[=Any] [--verbose[=Any]]" \
	  "$tooloo_hyphen_v" \
	  "should provide usage for tooloo -v"

  assert_status_code 2 "$TOOLOO_INVOCATION -v > /dev/null 2>&1"
}

test_02_confirm_no_db(){
	assert "test ! -e $DB_LOCATION"
}

test_03_list_empty(){
	no_content_output=$(XDG_DATA_HOME=$XDG_DATA_HOME $TOOLOO_INVOCATION list)
	assert_equals "Your database is currently empty." "$no_content_output"
}

test_04_hyphen_hyphen_version () {
  tooloo_hyphen_v=$(XDG_DATA_HOME=$XDG_DATA_HOME $TOOLOO_INVOCATION --version 2>&1 | sed -e "s/ running.*//")
  assert_equals "tooloo - provided by  ," "$tooloo_hyphen_v"\
	  "should provide usage for tooloo --version"

  assert_status_code 2 `$TOOLOO_INVOCATION --version > /dev/null 2>&1`
}

test_05_add_new() {
	file_path=$TEST_DATA_DIR"/raku_test_no_demo.meta.toml"
	add_new_output=$(XDG_DATA_HOME=$XDG_DATA_HOME $TOOLOO_INVOCATION add $file_path | sed -e "s/ \/.*//")
	assert_equals "Successfully ingested" "$add_new_output"
}

test_06_confirm_db(){
	assert "test -e $DB_LOCATION"
}

test_07_confirm_data() {
	commands_count=$(sqlite3 $DB_LOCATION 'select count(*) from commands');
	tags_count=$(sqlite3 $DB_LOCATION 'select count(*) from tags');
	commands_tags_count=$(sqlite3 $DB_LOCATION 'select count(*) from commands_tags');
	assert_equals "1" "$commands_count"
	assert_equals "2" "$tags_count"
	assert_equals "2" "$commands_tags_count"

}

test_08_add_existing() {
	file_path=$TEST_DATA_DIR"/raku_test_no_demo.meta.toml"
	add_existing_output=$(XDG_DATA_HOME=$XDG_DATA_HOME $TOOLOO_INVOCATION add $file_path | sed -e "s/ \/.*//")
	assert_equals "Successfully ingested" "$add_existing_output"
}

test_09_update() {
	file_path=$TEST_DATA_DIR"/raku_test_no_demo.meta.toml"
	update_output=$(XDG_DATA_HOME=$XDG_DATA_HOME $TOOLOO_INVOCATION update $file_path | sed -e "s/ \/.*//")
	assert_equals "Successfully ingested" "$update_output"
}

test_10_demo_missing_asciicast(){
	asciicast_output=$(XDG_DATA_HOME=$XDG_DATA_HOME $TOOLOO_INVOCATION demo raku_test_no_demo 2>&1 \
		| head -n1			)
	assert_equals "No asciicast url was specified for raku_test_no_demo" "$asciicast_output"
}

test_11_empty_demos_listing(){
	demos_output=$(XDG_DATA_HOME=$XDG_DATA_HOME $TOOLOO_INVOCATION demos )
	assert_equals "You don't have any commands with asciicast demos." "$demos_output"
}
test_12_add_asciicast() {
	file_path=$TEST_DATA_DIR"/raku_test_no_demo.cast"
	add_cast_output=$(XDG_DATA_HOME=$XDG_DATA_HOME $TOOLOO_INVOCATION update $file_path | sed -e "s/ \/.*//")
	assert_equals "Successfully ingested" "$add_cast_output"
}

test_13_demo_asciicast(){
	asciicast_output=$(XDG_DATA_HOME=$XDG_DATA_HOME $TOOLOO_INVOCATION demo raku_test_no_demo \
		| grep "echo" \
		| sed -e 's/^.* "//' -e 's/".*$//'			)
	assert_equals "test data" "$asciicast_output"
}
test_14_populated_demos_listing(){
	demos_output=$(XDG_DATA_HOME=$XDG_DATA_HOME $TOOLOO_INVOCATION demos | grep "raku_test_no_demo" )
	assert_equals "│ raku_test_no_demo │ raku_test_no_demo test description rtnddescription │" "$demos_output"
}

#  searching
# let's add a second one
test_15_add_second_command(){
	file_path=$TEST_DATA_DIR"/something_else.meta.toml"
	add_new_output=$(XDG_DATA_HOME=$XDG_DATA_HOME $TOOLOO_INVOCATION add $file_path | sed -e "s/ \/.*//")
	assert_equals "Successfully ingested" "$add_new_output"
}

test_16_list_shows_all(){
	list_output=$(XDG_DATA_HOME=$XDG_DATA_HOME $TOOLOO_INVOCATION list | wc -l | sed -e 's/^ *//')
	assert_equals "6" "$list_output"
}

test_17_filtered_list_is_filtered(){
	list_output=$(XDG_DATA_HOME=$XDG_DATA_HOME $TOOLOO_INVOCATION list demos | wc -l | sed -e 's/^ *//')
	assert_equals "5" "$list_output"
}

test_18_find_one_in_desc() {
	find_output=$(XDG_DATA_HOME=$XDG_DATA_HOME $TOOLOO_INVOCATION find rtnddescription | wc -l | sed -e 's/^ *//')
	assert_equals "5" "$find_output"
}
test_19_find_two_in_desc_with_same_term() {
	find_output=$(XDG_DATA_HOME=$XDG_DATA_HOME $TOOLOO_INVOCATION find description | wc -l | sed -e 's/^ *//')
	assert_equals "6" "$find_output"
}
test_20_find_two_in_desc_with_2_terms() {
	find_output=$(XDG_DATA_HOME=$XDG_DATA_HOME $TOOLOO_INVOCATION find rtnddescription sedescription  | wc -l | sed -e 's/^ *//')
	assert_equals "6" "$find_output"
}

test_21_find_two_in_desc_with_2_terms_1_result() {
	find_output=$(XDG_DATA_HOME=$XDG_DATA_HOME $TOOLOO_INVOCATION find rtnddescription booooogus  | wc -l | sed -e 's/^ *//')
	assert_equals "5" "$find_output"

}

test_22_stemming() {
	# the word in the data is "description" NOT "descriptions"
	find_output=$(XDG_DATA_HOME=$XDG_DATA_HOME $TOOLOO_INVOCATION find descriptions  | wc -l | sed -e 's/^ *//')
	assert_equals "6" "$find_output"
}

test_26_tag_search() {
	find_output=$(XDG_DATA_HOME=$XDG_DATA_HOME $TOOLOO_INVOCATION find se2  | wc -l | sed -e 's/^ *//')
	assert_equals "5" "$find_output"
}

test_27_tag_search_2_rows() {
	find_output=$(XDG_DATA_HOME=$XDG_DATA_HOME $TOOLOO_INVOCATION find se2  | wc -l | sed -e 's/^ *//')
	assert_equals "5" "$find_output"
}

# just confirming that it works and has the amount of output we're expecting
test_28_show() {
	show_output=$(XDG_DATA_HOME=$XDG_DATA_HOME $TOOLOO_INVOCATION show raku_test_no_demo  | wc -l | sed -e 's/^ *//')
	assert_equals "20" "$show_output"
}

test_29_template() {
	template_destination=$XDG_CONFIG_HOME"/tooloo/created_template.meta.toml"
	creation_output=$(XDG_CONFIG_HOME=$XDG_CONFIG_HOME $TOOLOO_INVOCATION template $template_destination | sed -e "s/ to .*//")
	assert_equals "Copying fresh template" "$creation_output"
	assert "test -e $template_destination"
	rm $template_destination

}
