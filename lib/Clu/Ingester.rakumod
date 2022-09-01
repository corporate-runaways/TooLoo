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
	$db.finish;
}

our sub find-command-id($command_name, DB::SQLite $db) returns Maybe[Int] {
	my $val = $db.query('SELECT id FROM commands WHERE name=$name', name => $command_name).value;
	$val !~~ Nil ?? something($val) !! nothing(Int);
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
	my $update_sql = q:to/END/;
UPDATE commands SET
  name				= ?,
  description		= ?,
  usage_command		= ?,
  fallback_usage	= ?,
  type				= ?,
  language			= ?,
  source_url		= ?,
  source_repo_url	= ?
WHERE id=?
END

   my $statement_handle = $db.db.prepare($update_sql);
   my $list_with_id = flat(executable-list(%command), $id).List;
   say("\n\nXXX list_with_id: " ~ $list_with_id.raku ~ "\n\n");
   say("\n\nXXX list_with_id.^name: " ~ $list_with_id.^name ~ "\n\n");
   $statement_handle.execute($list_with_id);
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
