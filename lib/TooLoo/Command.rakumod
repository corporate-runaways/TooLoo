# =begin pod
# =head1 TooLoo::Command
# =para
# A Command has the following attributes (columns)
#
# =defn id
# incrementing integer id

# =defn name
# the name of the command (what you execute)

# =defn description
# a short description of what the command does

# =defn usage_command
# the command to execute to retrieve the commands current usage output

# =defn fallback_usage
# if the command doesn't have the ability to output usage then this
# would contain manually specified usage instructions

# =defn location
# where this command is installed on this computer

# =defn type
# executable, function, alias

# =defn language
# what language was this command written in

# =defn source_url
# an url where you can see the source of this particular command
#
# =defn source_repo_url
# the source code repository (not always git)

# =end pod

unit module TooLoo::Command:ver<2.0.0>:auth<masukomi (masukomi@masukomi.org)>;
use Color;
use DB::Connection;
use DB::SQLite::Statement;
use DB::SQLite;
use Definitely;
use Listicles;
use Prettier::Table;
use Terminal::ANSIColor;
use Terminal::Width;
use Text::MiscUtils::Layout;
use TooLoo::Metadata;
use TooLoo::TerminalUtilities;



multi sub display-command(%command) is export {
	my $location = find-commands-location(%command<name>);
	if ($location eq "UNKNOWN") and %command<location> {
		$location = %command<location>;
	}

	my $table = Prettier::Table.new(
		field-names => ['Attribute', 'Detail'],
								     align => %('Attribute' => 'l', 'Detail' => 'l'));
	$table.add-row(['command', %command<name>]);
	$table.add-row(['short description', %command<short_description>]);
	if %command<description> {
		$table.add-row(['', '']);
		$table.add-row(['full description', %command<description>]);
	}
	$table.add-row(['', '']);
	$table.add-row(['usage', extract-command-usage(%command)]);
	$table.add-row(['type',  (%command<type> or "UNKNOWN")]);
	$table.add-row(['language',  (%command<language> or "UNKNOWN")]);
	$table.add-row(['location', $location]);
	if %command.<source_repo_url> {
		$table.add-row(['source repo', %command<source_repo_url>]);
	}
	if %command.<source_url> {
		$table.add-row(['source url', %command<source_url>]);
	}
	if %command.<asciicast_url> {
		$table.add-row(['asciicast url', %command<asciicast_url>]);
	}

	if ! %command<tags>.is-empty {
		$table.add-row(['tags', %command<tags>.join(', ')]);
	}


	say $table;
}

our sub find-commands(Str $search_string, DB::Connection $connection) returns Maybe[Array] {
	#TODO REFACTOR THIS INTO MULTIPLE SMALL METHODS

	# WHERE foo MATCH IN (...) is NOT AN OPTION
	# you can't join AND match...
	# MATCH has to be executed before the JOIN (subselects)

	# MATCH works only on the FTS table itself,
	# so it must be executed before a join.
	#
	# writing a single query that bridged these tables seems
	# convoluted at best.
	#
	# Instead, we're going to do multiple queries,
	# uniquify the ids that come back, and then
	# search for _those_ commands.
	#
	#
	my @terms_list = $search_string.subst(/<[,/]>+/, "", :g).split(/\s+/);
	# the four $_ below correspond to name, short_description, description, and language
	my @command_search_bindings = [].push(@terms_list.map({[$_, $_, $_, $_ ]}));
	my $tag_search_sql = q:to/END/;
		SELECT id FROM tags_fts WHERE
		tag MATCH 'bogus_because_this_is_a_terrible_tag'
	END

	# the weird 1=0 is just to have something
	# that always tests false, that we can ignore
	# and allows us to make the next thing
	# we append always start with OR (easier for loop)
	my $command_search_sql = q:to/END/;
        SELECT id FROM commands_fts WHERE
		  id MATCH 'bogus_because_ids_are_always_numbers'
	END

	for @terms_list -> $term {
		$tag_search_sql ~= ' OR tag MATCH ?';

		$command_search_sql ~= q:to/END/;

		OR name MATCH				?
		OR short_description MATCH	?
		OR description MATCH		?
		OR language MATCH			?
		END
	}

	$command_search_sql ~= ' ORDER BY rank;';
	@command_search_bindings = @command_search_bindings.flatten;
	my @command_ids = $connection\
					.query(
						$command_search_sql,
						@command_search_bindings
					)\
					.arrays.map({ $_[0] });
	my @tag_ids = $connection\
				   .query($tag_search_sql, @terms_list)\
				   .arrays.map({ $_[0] });



	# NOTE: DB::SQLite driver isn't smart enough to map LIST to single ?
	# in order to do an "in (?)"
	# or to bind "in (:foo)"
	#
	# applies to this and next query
	my $joined_tag_ids = @tag_ids.join(", ");
	my $commands_tags_search_sql = qq:to/END/;
		SELECT command_id FROM commands_tags
		WHERE
			tag_id IN ($joined_tag_ids)
	END
	my @other_command_ids = $connection.query(
			$commands_tags_search_sql
		)\
		.arrays.map({$_[0]});
	@command_ids.append(@other_command_ids);


    my $joined_command_ids = @command_ids.join(", ");
	my $search_sql = qq:to/END/;
		SELECT * from commands where id IN ($joined_command_ids)
	END
	my @results = $connection.query($search_sql).hashes;
	if @results.elems > 0 {
		return something(@results);
	} else {
		return nothing(Array);
	}
}

our sub find-command-id(Str $command_name, DB::Connection $connection) returns Maybe[Int] is export {
	# WARN .connections only works becaues of custom build of DB package
	my $val = $connection.query('SELECT id FROM commands WHERE name=$name', name => $command_name).value;
	$val ~~ Int ?? something($val) !! nothing(Int);
}

our sub load-command(Str $command_name, DB::Connection $connection) returns Maybe[Hash] is export {
	given $connection.query('select * from commands where name = ?', $command_name).hash {
		when $_.elems > 0 {
			something($_);
		}
		default {
			nothing(Hash);
		}
	}
}

our sub display-names-and-short-descriptions(@commands) {
	my $table = Prettier::Table.new(
		field-names => ['Command', 'Description'],
		align => %('Command' => 'l', 'Description' => 'l')
	);
	for @commands -> %command {
		$table.add-row([%command<name>, %command<short_description>])
	}
	say $table;

}
my sub extract-command-usage(%command --> Str) is export {
	if %command<usage_command> {
		# prints to STDOUT and/or STDERR
		my $usage_proc  = (shell %command<usage_command>, out => True, err => False );
		if $usage_proc.exitcode == 0 {
			# this is, FULLY ridiculous, and demands an explanation
			# "man" is at least somewhat broken on macos.
			# "man ls | head -n 4" output includes these 2 lines.
			#
			# NNAAMMEE
			#     llss – list directory contents
			#
			# Those ^H characters are backspace characters.
			# It's printing, and then deleting and then reprinting every letter in NAME
			# and the first couple of real characters from the next line.
			#
			# as some commands have their usage in man pages... we're going to encounter this.
			# backspace is \x08 so
			return colorstrip($usage_proc
				.out
				.slurp(:close)
				.subst(/. \x08 | \x08 /, "", :g));
		}
	}

	return %command<fallback_usage> if %command<fallback_usage>;
	note("Unable to determine usage for %command<name>");
	"USAGE UNKNOWN"
}

our sub search-and-display(Str $search_string, DB::SQLite $sqlite) is export {
	my $connection = $sqlite.db;
	my $results_maybe = find-commands($search_string, $connection);
	if $results_maybe !~~ Some {
		say("No matches found");
	    return;
	}
	my @results = $results_maybe.value[];
	display-names-and-short-descriptions(@results);
}

multi sub display-command(Str $command_name, DB::SQLite $sqlite) is export {
	my $connection = $sqlite.db;
	my $command_data = load-command($command_name, $connection);
	unless $command_data ~~ Some {
		note("No data found for $command_name");
		exit 0;
	}

	my $unwrapped_data = $command_data.value;
	$unwrapped_data<tags> = get-tags-for-command($unwrapped_data<id>,
											   $connection);
	display-command($unwrapped_data);
}

#| returns list of hashes with name & short_description of each command
our sub get-quick-list(DB::Connection $connection) returns Seq is export {
	my $search_sql = q:to/END/;
		SELECT name, short_description FROM commands ORDER BY name ASC;
	END
	$connection.query($search_sql).hashes ;
}

#| displays list of all commands with name & short description
multi sub list-all-commands(DB::SQLite $sqlite) is export {
	my @results = get-quick-list($sqlite.db);
	if @results.elems > 0 {
		display-names-and-short-descriptions(@results);
	} else {
		say("Your database is currently empty.")
	}
	$sqlite.finish();
}

multi sub list-all-demos(DB::SQLite $db) is export {
	my $search_sql = q:to/END/;
		SELECT name, short_description
		FROM commands
		WHERE asciicast_url is not null
		ORDER BY name ASC;
	END
	my @results = $db.query($search_sql).hashes ;
	if @results.elems > 0 {
		display-names-and-short-descriptions(@results);
	} else {
		say("You don't have any commands with asciicast demos.")
	}
	$db.finish();
}

#--------------------------
# Tag Stuff

my sub find-tag-records(@tags, DB::Connection $connection) returns Seq {
	return [].Seq if @tags.is-empty;

	my $tags_list = "'" ~ @tags.join("', '") ~ "'";
	my $search_sql = qq:to/END/;
		SELECT * FROM tags WHERE
		tag in ($tags_list)
		ORDER BY tag ASC;
	END
	# my $tags_list = "'" ~ @tags.join("', '") ~ "'";

	# my $result  = $connection.query($search_sql, $tags_list) ;
	my $result  = $connection.query($search_sql) ;
	return $result.arrays;
}

# - takes a list of tags, adds the new ones
# - returns Seq of tag + id lists
#  $(((2, "debugging"), (1, "ruby")).Seq
my sub add-tags(@tags, DB::Connection $connection) returns Seq {

	# for @tags -> $tag {
	# 	$connection.execute("INSERT INTO tags (tag) VALUES ('$tag')");
	# 	# my $tag_id =  $connection.query("select id from tags where tag = '$tag'; ").value;
	# }



	my @known_tags = find-tag-records(@tags, $connection);
	my @extant_tag_names = @known_tags.map({.[1]});
	# NOTE: that's not a backslash below. It's a "SET MINUS" (\u002216)
	my @new_tags = @tags.Set ∖ @extant_tag_names; # Seq of Pairs
	if ! @new_tags.is-empty {
		my $insert_sql = q:to/END/;
			INSERT INTO TAGS (tag) VALUES
		END

		for (1..@new_tags.elems) {
			$insert_sql ~= " ( ? ),";
		}
		# trim off the last comma
		$insert_sql = substr($insert_sql, 0, *-1);


		# it's a sequence of Pairs, we need an Array of Strings
		my $new_tag_strings = @new_tags.map(*.key).Array;

		my $statement_handle = $connection.prepare($insert_sql);
		my $rows_changed = $statement_handle.execute(|$new_tag_strings);

	}
	return find-tag-records(@tags, $connection);
}

#| Severs the associations between a command and its tags (if any).
my sub delete-commands-tags(Int $command_id, DB::Connection $connection) is export returns Int {
    # my $count = $connection.query("select count(*) from commands_tags where command_id = $command_id").value;
	# if $count > 0 {
		my $delete_sql = "DELETE from commands_tags where command_id = ?";
		my $statement_handle = $connection.prepare($delete_sql);
		return $statement_handle.execute($command_id);
	# }
	# return 0;
}

#| record a list of new/updated tags for the specified command
our sub set-tags-for-command(Int $command_id, @tags, DB::Connection $connection) is export returns Bool {


	my $deleted_connections_count = delete-commands-tags($command_id, $connection);
	my $ids_and_tags = add-tags(@tags.cache, $connection).cache;

	# return early if there's nothing new to inserts
	return True if $ids_and_tags.Seq.is-empty;

	my $insert_sql = 'INSERT INTO commands_tags (command_id, tag_id) VALUES ';

	# these are just IDs, that WE retrieved,
	# so i'm not worried about SQL injection
	for $ids_and_tags.Array -> $tag_tuple {
		$insert_sql ~= " ( $command_id, $tag_tuple[0] ),";
	}
	$insert_sql = substr($insert_sql, 0, *-1);
	$connection.query($insert_sql);

	True
}

proto get-tags-for-command(Int $command_id, |) is export returns Array {*}

multi get-tags-for-command(Int $command_id, DB::Connection $connection) is export returns Array {
	my $sth = get-tags-for-command-statement-handle($connection);
	get-tags-for-command($command_id, $sth)
}

multi get-tags-for-command(Int $command_id, DB::SQLite::Statement $statement_handle) is export returns Array {
	$statement_handle
						 .execute($command_id)
						 .arrays
						 .flatten
						 .Array;

}
our sub get-tags-for-command-statement-handle(DB::Connection $connection) is export returns DB::SQLite::Statement {
	my $tags_search_sql = q:to/END/;
		select tag from commands_tags ct
		inner join tags t on ct.tag_id = t.id
		where command_id = ?;
	END
	my $tags_statement_handle = $connection.prepare($tags_search_sql);
}
