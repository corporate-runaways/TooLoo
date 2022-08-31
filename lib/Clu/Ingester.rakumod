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

our sub ingest-metadata(Str $path, DB::SQLite $db) is export returns Bool{
	#TODO: convert relative paths to absolute
	# convert ~ to $*HOME
	$path = $path.subst(/^^ "~"/, $*HOME)

	# test if the file exists at that path
	die unless $path.IO.e
	# read the file
	# parse the toml
	my %metadata = from-toml($path.IO.slurp);
	# ^ that doesn't fail if it's not TOML
	# BUT %config.^name would be "Any" in that case, so...
	die("$path didn't appear to contain valid TOML") unless %metadata.^name eq "Hash";
	die("$path didn't have a 'name' key") unless %metadata<name>.Bool;
	die("$path didn't have a 'description' key") unless %metadata<description>.Bool;
	# see if anything exists in the db for that command
	given find-command-id($metadata<name>) {
		# if yes, update
		when $_ Some {
			update-command($_.value, %metadata, $db);
		}
		# if no, insert
		default {
			insert-command(%metadata, $db);
		}
	}
	$db.finish;
}

our sub insert-command(%command){

}
our sub update-command($id, %command){
	my $update_sql = q:to/END/;
UPDATE commands SET
  name				= $name,
  description		= $description,
  usage_command		= $usage_command,
  fallback_usage	= $fallback_usage,
  type				= $type,
  language			= $language,
  source_url		= $source_url,
  source_repo_url	= $source_repo_url
WHERE id=$id
END

   my $statment_handle = $db.prepare($update_sql);
   $statement_handle.execute(
	   self.executable-hash(%command).push('id', $id)
   );
}

our sub executable-hash(Hash %command) returns Hash {
	   name				=> %command<name>, # guaranteed present
	   description		=> %command<description>,
	   usage_command	=> %command<usage_command> or Nil,
	   fallback_usage	=> %command<fallback_usage> or Nil,
	   type				=> %command<type> or Nil,
	   language			=> %command<language> or Nil,
	   source_url		=> %command<source_url> or Nil,
	   sourc_repo_url	=> %command<source_repo_url> or Nil
}
our sub find-command-id($command_name, DB::SQLite $db) returns Maybe[Int] {
	my $val = $s.query('SELECT id FROM commands WHERE name=$name', name => $command_name).value;
	$val === Nil ?? something($val) !! nothing(Maybe[Int]);
}
