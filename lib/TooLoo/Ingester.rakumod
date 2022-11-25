# =begin pod
# =head1 TooLoo::Ingester
# =para
# Ingests a TOML file with information about a command.
#
# =end pod

unit module TooLoo::Ingester:ver<1.0.1>:auth<masukomi (masukomi@masukomi.org)>;
use TooLoo::Command;
use TooLoo::TerminalUtilities;
use DB::SQLite;
use Definitely;
use TOML;
use File::Find;
use TooLoo::Asciicaster;

our sub mass-ingestion(Str $path, DB::SQLite $sqlite) returns Bool is export {
	say("Beginning ingestion of .toml & .cast files in $path");
	my $cleaned_path = expand-tilde($path);
	my $counter = 0;
	my @toml_files = find dir => $cleaned_path, name => /'.toml' $ | '.cast' $/;
	if @toml_files.elems > 0 {
		my $connection = $sqlite.db;
		# the reverse is important.
		# .cast comes before .toml alphabetically
		# So, if this is a new command the .cast will error
		# because the .toml hasn't been ingested yet
		# If we process these in reverse order we'll
		# document the command BEFORE we try and associate a cast with it.
		for @toml_files.reverse -> $toml_or_clu {
			say("Considering $toml_or_clu");
			if $toml_or_clu.ends-with('.toml') {
				$counter++ if ingest-metadata-io($toml_or_clu, $connection,
											die_on_error => False);
			} else {
				$counter++ if add-asciicast-io($toml_or_clu, $connection);
			}
		}
		say("$counter files were successfuly ingested out of " ~ @toml_files.elems
			~ " total files with .toml or .cast extensions.");
	} else {
		say("I didn't find any .toml or .cast files to ingest in $cleaned_path");
	}

	True
}



proto ingest-metadata(Str $path, |){*}
multi ingest-metadata(Str $path, DB::SQLite $sqlite) returns Bool is export {
	ingest-metadata($path, $sqlite.db);
}
multi ingest-metadata(Str $path,
					  DB::Connection $connection,
					  Bool :$die_on_error=True) returns Bool is export {

	my $cleaned_path = expand-tilde($path);
	my $io_path = IO::Path.new($cleaned_path);
	ingest-metadata-io($io_path, $connection, die_on_error => $die_on_error);
}
my sub ingest-metadata-io(IO::Path $io_path,
					  DB::Connection $connection,
					  Bool :$die_on_error=True) returns Bool is export {
	die-or-note("$io_path doesn't end with .toml", $die_on_error)         unless $io_path.Str.ends-with('.toml');
	# test if the file exists at that io_path
	die-or-note("$io_path doesn't exist", $die_on_error)                  unless $io_path.e;
	# read the file
	# parse the toml
	my %metadata = from-toml($io_path.slurp);
	# ^ that doesn't fail if it's not TOML
	# BUT %config.^name would be "Any" in that case, so...
	die-or-note("$io_path didn't appear to contain valid TOML", $die_on_error) \
		unless %metadata.^name eq "Hash";
	die-or-note("$io_path didn't have a 'name' key", $die_on_error) \
		unless validate-presence(%metadata<name>);
	die-or-note("$io_path didn't have a 'short_description' key", $die_on_error) \
		unless validate-presence(%metadata<short_description>);

	# see if anything exists in the db for that command
	given find-command-id(%metadata<name>, $connection) {
		# if yes, update
		when $_ ~~ Some {
			update-command($_.value, %metadata, $connection);
		}
		# if no, insert
		default {
			insert-command(%metadata, $connection);
		}
	}
	return True;
	CATCH {
     default {
		$*ERR.say: .message;
		return False
	 }
	}
}

my sub validate-presence(Any $x --> Bool) {
	return False if Nil ~~ $x;
	return ! ! $x.match(/\S+/);
}

our sub insert-command(%command, DB::Connection $connection){
	my $insert_sql = q:to/END/;
INSERT INTO commands (
	name,
	short_description,
	description,
	usage_command,
	fallback_usage,
	type,
	language,
	source_url,
	source_repo_url,
	asciicast_url
) VALUES (
	?,
	?,
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
	my $statement_handle = $connection.prepare($insert_sql);
	$statement_handle.execute(executable-list(%command));
	# $statement_handle.finish();

	my @command_tags = %command<tags>;
	if ! @command_tags.is-empty {
		# we'll need the auto-generated ID of the thing we just inserted
		my $command_id = find-command-id(%command<name>, $connection);
		if $command_id ~~ Some {
			$command_id = $command_id.value;
			set-tags-for-command($command_id, (%command<tags> or []), $connection);

			# this is stupid, I admit, but because of the triggers that update
			# the virtual table, it's actually cleaner to update this with a bs
			# whitespace change than have multiple PITA triggers on the tags and / or
			# commands_tags table.
			my $update_sql = q:to/END/;
				UPDATE commands set short_description = ?
				WHERE id = ?
			END
			my $statement_handle = $connection.prepare($update_sql);
			$statement_handle.execute([(%command<short_description> ~ " "), $command_id]);
		}
	}

}

our sub update-command($command_id, %command, DB::Connection $connection){
	# there's a bug in DB::SQLite
	# https://github.com/CurtTilmes/raku-dbsqlite/issues/18
	# you can't used named parms with
	# .execute unless you bind them each individually

	# there's no trigger on tags, or commands_tags
	# so we need to update this before we update the
	# command itself, because _that_ table has a trigger
	set-tags-for-command($command_id, (%command<tags> or []), $connection);

	my $update_sql = q:to/END/;
UPDATE commands SET
  name              = ?,
  short_description = ?,
  description       = ?,
  usage_command     = ?,
  fallback_usage    = ?,
  type              = ?,
  language          = ?,
  source_url        = ?,
  source_repo_url   = ?,
  asciicast_url     = ?

WHERE id = ?;
END

   my $statement_handle = $connection.prepare($update_sql);
   my @list_with_id = executable-list(%command);
   @list_with_id.append($command_id);
   $statement_handle.execute(@list_with_id);
}

sub remove-command(Str $command_name, DB::SQLite $sqlite) returns Bool is export {
	my $connection = $sqlite.db;
	my $command_id = find-command-id($command_name, $connection);
    if $command_id ~~ Some {
		$command_id = $command_id.value;
		delete-commands-tags($command_id, $connection);
		my $delete_sql = "DELETE FROM commands WHERE name = :command_name";
		my $statement_handle = $connection.prepare($delete_sql);
		$statement_handle.bind(':command_name', $command_name);
		my $rows_affected = $statement_handle.execute();
		return ($rows_affected > 0 ?? True !! False);
	}
	return False;
}


our sub executable-list(%command) {
	   [
		   %command<name>, # guaranteed present
		    %command<short_description>,
			%command<description>,
			(%command<usage_command> or Nil),
			( %command<fallback_usage> or Nil ),
			( %command<type> or Nil ),
			( %command<language> or Nil ),
			( %command<source_url> or Nil ),
			( %command<source_repo_url> or Nil ),
			( %command<asciicast_url> or Nil )
	   ]
}

my sub die-or-note(Str $message, Bool $die) {
	die($message) if $die;
	note($message);
}
# commenting out until the DB::SQLite bug is fixed
# https://github.com/CurtTilmes/raku-dbsqlite/issues/18
# our sub executable-hash(%command) {
# 	   name				=> %command<name>, # guaranteed present
# 	   description		=> %command<description>,
# 	   usage_command	=> ( %command<usage_command> or Nil ),
# 	   fallback_usage	=> ( %command<fallback_usage> or Nil ),
# 	   type				=> ( %command<type> or Nil ),
# 	   language			=> ( %command<language> or Nil ),
# 	   source_url		=> ( %command<source_url> or Nil ),
# 	   sourc_repo_url	=> ( %command<source_repo_url> or Nil )
# }
