# =begin pod
# =head1 Clu::Ingester
# =para
# Ingests a TOML file with information about a command.
#
# =end pod

unit module Clu::Command:ver<1.0.0>:auth<masukomi (masukomi@masukomi.org)>;
use Definitely;
use Terminal::ANSIColor;
use Text::MiscUtils::Layout;
use Clu::TerminalUtilities;
use Color;
use DB::SQLite;
use TOML;

our sub ingest-metadata(Str $path, DB::SQLite $db) returns Bool is export {
	#TODO: convert relative paths to absolute
	# convert ~ to $*HOME
	my $cleaned_path = $path.subst(/^^ "~"/, $*HOME);

	die("$cleaned_path doesn't end with .toml")                 unless $cleaned_path.ends-with('.toml');
	# test if the file exists at that cleaned_path
	die("$cleaned_path doesn't exist")                          unless $cleaned_path.IO.e;
	# read the file
	# parse the toml
	my %metadata = from-toml($cleaned_path.IO.slurp);
	# ^ that doesn't fail if it's not TOML
	# BUT %config.^name would be "Any" in that case, so...
	die("$path didn't appear to contain valid TOML")	unless %metadata.^name eq "Hash";
	die("$path didn't have a 'name' key")				unless %metadata<name>.Bool;
	die("$path didn't have a 'description' key")		unless %metadata<description>.Bool;
	# see if anything exists in the db for that command
	given find-command-id(%metadata<name>, $db) {
		# if yes, update
		when $_ ~~ Some {
			say("maybe from db = " ~ $_.raku);

			update-command($_.value, %metadata, $db);
		}
		# if no, insert
		default {
			say("maybe from db = " ~ $_.raku);
			insert-command(%metadata, $db);
		}
	}
	return True;
}

our sub find-command-id($command_name, DB::SQLite $db) returns Maybe[Int] {
	my $val = $db.query('SELECT id FROM commands WHERE name=$name', name => $command_name).value;
	say("XXX \$val is a " ~ $val.^name ~ " with the value of " ~ $val.raku);
	$val ~~ Int ?? something($val) !! nothing(Int);
}
our sub insert-command(%command, $db){
	my $insert_sql = q:to/END/;
INSERT INTO commands (
	name,
	description,
	usage_command,
	fallback_usage,
	type,
	language,
	source_url,
	source_repo_url
) VALUES (
	?,
	?,
	?,
	?,
	?,
	?,
	?,
	?
);
END
   my $statement_handle = $db.db.prepare($insert_sql);
   $statement_handle.execute(executable-list(%command));

}

our sub update-command($id, %command, $db){
  # usage_command = $usage_command,
  # fallback_usage	= $fallback_usage,
  # type				= $type,
  # language			= $language,
  # source_url		= $source_url,
  # source_repo_url	= $source_repo_url

	my $update_sql = q:to/END/;
UPDATE commands SET
  name				= $name,
  description = $description,
  usage_command = $usage_command,
  fallback_usage	= $fallback_usage,
  type				= $type,
  language			= $language,
  source_url		= $source_url,
  source_repo_url	= $source_repo_url

WHERE id = $id;
END

# UPDATE commands SET description='d1' where id = 1;
# my $update_sql = q:to/END/;
# UPDATE commands SET description = $description where id = 1;
# END

#FIXME
# the current problem is the create_fts_au trigger
# TODO:
# - [x] keep experimenting with the trigger in DB Browser
# - [x] try and get the 1st part (insert...delete) working
# - [ ] then get the 2nd part inserting the new data working
# - [ ] THEN come back here, and see if we can get this working as-is
# - [ ] then see if we can get it working with the named params
#   using manual single binds
# - [ ] then see if we can get it working with the executable-hash + id
# - [ ] then see if we can get the insert working with named params again.
   say("XXX update_sql: " ~ $update_sql.raku);
	say("XXX id to update: $id");
   say("XXX command: " ~ %command.raku ~ "\n\n");


   my $statement_handle = $db.db.prepare($update_sql);
   # my $list_with_id = flat(executable-list(%command), $id).List;
   # say("\n\nXXX list_with_id: " ~ $list_with_id.raku ~ "\n\n");
   # say("\n\nXXX list_with_id.^name: " ~ $list_with_id.^name ~ "\n\n");
   $statement_handle.bind('$name', %command<name>);
   $statement_handle.bind('$description', %command<description>);
   $statement_handle.bind('$usage_command', (%command<usage_command> or Nil));
   $statement_handle.bind('$fallback_usage', (%command<fallback_usage> or Nil));
   $statement_handle.bind('$type', (%command<type> or Nil));
   $statement_handle.bind('$language', (%command<language> or Nil));
   $statement_handle.bind('$source_url', (%command<source_url> or Nil));
   $statement_handle.bind('$source_repo_url', (%command<source_repo_url> or Nil));
   $statement_handle.bind('$id', $id);

   say("XXX execute response: " ~ $statement_handle.execute().raku);
   # my %binding_data = executable-hash(%command);
   # %binding_data<id> = $id;
   # THERE IS A BUG in DB::SQLite's execute method
   # it will always error when given named parameters.
   #
   # BUT IT does support a list of params and would likely work with params identified as
   # ?NNN which wouldn't be helpful because you can't pass in an array of named items
   # or just ? which would probably be easiest and we could use
   # executable-list -> list_with_id

   # $statement_handle.bind(%binding_data);
   # $statement_handle.execute(%binding_data);
   # my @list_binding_data = (%binding_data.keys Z %binding_data.values).flat;
   # say("XXX execute response: " ~ $statement_handle.execute(False, False, %binding_data).raku);

	   # $list_with_id);
}

our sub executable-list(%command) {
	   (
		   %command<name>, # guaranteed present
			%command<description>,
			(%command<usage_command> or Nil),
			( %command<fallback_usage> or Nil ),
			( %command<type> or Nil ),
			( %command<language> or Nil ),
			( %command<source_url> or Nil ),
			( %command<source_repo_url> or Nil )
	   )
}
our sub executable-hash(%command) {
	   name				=> %command<name>, # guaranteed present
	   description		=> %command<description>,
	   usage_command	=> ( %command<usage_command> or Nil ),
	   fallback_usage	=> ( %command<fallback_usage> or Nil ),
	   type				=> ( %command<type> or Nil ),
	   language			=> ( %command<language> or Nil ),
	   source_url		=> ( %command<source_url> or Nil ),
	   sourc_repo_url	=> ( %command<source_repo_url> or Nil )
}
