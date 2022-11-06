# =begin pod
# =head1 Clu::Command
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

unit module Clu::Command:ver<1.0.1>:auth<masukomi (masukomi@masukomi.org)>;
use Definitely;
use Terminal::ANSIColor;
use Terminal::Width;
use Text::MiscUtils::Layout;
use Clu::TerminalUtilities;
use Color;
use DB::SQLite;


multi sub display-command(%command) is export {
# sub display-command(Hash:D %command) is export {
    #TODO: improve coloring
	display-name-and-description(%command);
	display-usage(%command);
	display-metadata(%command);

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
	# the three $_ below correspond to name, description, and language
	my @command_search_bindings = [].push(@terms_list.map({[$_, $_, $_ ]}));
	my $tag_search_sql = q:to/END/;
		SELECT id from tags_fts where tag MATCH ?
	END

	my $command_search_sql = q:to/END/;
        SELECT id FROM commands_fts WHERE
          name MATCH ?
          OR description MATCH ?
          OR language MATCH ?
	END

	if @terms_list.elems > 1 {
		for @terms_list -> $term {
			$tag_search_sql ~= ' OR tag MATCH ?';

			$command_search_sql ~= q:to/END/;
			OR name MATCH ?
			OR description MATCH ?
			OR language MATCH ?
			END
		}

	} else {
		$command_search_sql ~= ' ORDER BY rank;';
	}

	my @command_ids = $connection\
					.query(
						$command_search_sql,
						@command_search_bindings.flatten
					)\
					.arrays.map({ $_[0] });
	my @tag_ids = $connection\
				   .query($tag_search_sql, @terms_list)\
				   .arrays.map({ $_[0] });



	my $commands_tag_search_sql = q:to/END/;
		SELECT command_id FROM commands_tags
		WHERE
			tag_id IN (?)
	END
	my @other_command_ids = $connection.query(
			$commands_tag_search_sql,
			@tag_ids
		)\
		.arrays.map({$_[0]});
	@command_ids.append(@other_command_ids);


	# NOTE: driver isn't smart enough to map LIST to single ?
	# in order to do an "in (?)"
	# or to bind "in (:foo)"
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


#FIXME
our sub display-metadata(%command) {
# sub ansi-display-metadata(Hash %command) {
	# say colored( ("-" x terminal-width(:default<80>)), 'bold');
	# ^^ dynamic width causes tests to fail.
	# TODO: find a way to force a width in Terminal::Width for testing
	say colored( ("-" x 20), 'bold');

	say colored("type: ", 'bold') ~  (%command<type> or "UNKNOWN");
	say colored("lang: ", 'bold') ~ (%command<language> or "UNKNOWN");
	my $where_proc = run "command", "-v", %command<name>, :out, :err;
	say colored("location: ", 'bold') ~ ($where_proc.exitcode == 0
						?? $where_proc.out.slurp(:close)
						!! (%command<location> or "UNKNOWN"));
	if %command.<source_repo_url> {
		say colored("source repo: ", 'bold') ~ %command<source_repo_url>;
	}
	if %command.<source_url> {
		say colored("source url: ", 'bold') ~ %command<source_url>;
	}
	if %command.<asciicast_url> {
		say colored("asciicast url: ", 'bold') ~ %command<asciicast_url>;
	}
}

our sub display-name-and-description(%command) {
# sub ansi-display-name-and-description(Hash %command) {
	my $separator = ' : ';
	my $wrapped_desc = wrap-with-indent(
		(%command<name>.elems + $separator.elems),
		%command<description>
       );

    say colored("%command<name>" ~ $separator ~ "$wrapped_desc\n", "bold underline" );
}

our sub display-names-and-descriptions(@commands) {
	# find the longest command name
	my $max_name_length = 0;

	for @commands -> %command {
		my $length = %command<name>.chars;
		if $length > $max_name_length {
			$max_name_length = $length;
		}
	}

	my $term_width = terminal-width(:default<80>);
	my $max_description_width = $term_width - ( $max_name_length + 3 );
	# term_width - (max_name_length + " | " )

	for @commands -> %command {
		("%-$max_name_length" ~ "s | %.$max_description_width" ~ "s\n").printf(%command<name>, %command<description>)
	}
}

our sub display-usage(%command) {
# sub ansi-display-usage(Hash %command) {
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
			my $output = $usage_proc.out.slurp(:close).subst(/. \x08 | \x08 /, "", :g);
			say $output;
		} else {
			display-fallback-usage(%command);
		}
	} else {
		display-fallback-usage(%command);
	}
}

our sub display-fallback-usage(%command){
	if %command<fallback_usage> {
		say %command<fallback_usage>;
	} else {
		say colored("USAGE UNKNOWN",
					"{%COLORS<WARNING_FOREGROUND>} on_{%COLORS<WARNING_BACKGROUND>}");
	}
}

our sub search-and-display(Str $search_string, DB::SQLite $sqlite) is export {
	my $connection = $sqlite.db;
	my $results_maybe = find-commands($search_string, $connection);
	if $results_maybe !~~ Some {
		say("No matches found");
	    return;
	}
	my @results = $results_maybe.value[];
	display-names-and-descriptions(@results);
}

multi sub display-command(Str $command_name, DB::SQLite $sqlite) is export {
	my $command_data = load-command($command_name, $sqlite.db);
	unless $command_data ~~ Some {
		note("No data found for $command_name");
		exit 0;
	}
	display-command($command_data.value);
}

multi sub list-all-commands(DB::SQLite $db) is export {
	my $search_sql = q:to/END/;
		SELECT name, description FROM commands ORDER BY name ASC;
	END
	my @results = $db.query($search_sql).hashes ;
	if @results.elems > 0 {
		display-names-and-descriptions(@results);
	} else {
		say("Your database is currently empty.")
	}
	$db.finish();
}
multi sub list-all-demos(DB::SQLite $db) is export {
	my $search_sql = q:to/END/;
		SELECT name, description
		FROM commands
		WHERE asciicast_url is not null
		ORDER BY name ASC;
	END
	my @results = $db.query($search_sql).hashes ;
	if @results.elems > 0 {
		display-names-and-descriptions(@results);
	} else {
		say("You don't have any commands with asciicast demos.")
	}
	$db.finish();
}
