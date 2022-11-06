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
use Prettier::Table;
use Color;
use DB::SQLite;


multi sub display-command(%command) is export {
	my $where_proc = run "command", "-v", %command<name>, :out, :err;
	my $location   = ($where_proc.exitcode == 0
						?? $where_proc.out.slurp(:close).trim
						!! (%command<location> or "UNKNOWN"));

	my $table = Prettier::Table.new(
		field-names => ['Attribute', 'Detail'],
								     align => %('Attribute' => 'l', 'Detail' => 'l'));
	$table.add-row(['command', %command<name>]);
	$table.add-row(['description', %command<description>]);
	$table.add-row(['', '']);
	$table.add-row(['usage', extract-usage(%command)]);
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
	# the three $_ below correspond to name, description, and language
	my @command_search_bindings = [].push(@terms_list.map({[$_, $_, $_ ]}));
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

		OR name MATCH ?
		OR description MATCH ?
		OR language MATCH ?
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
	# my $max_name_length = 0;

	# for @commands -> %command {
	# 	my $length = %command<name>.chars;
	# 	if $length > $max_name_length {
	# 		$max_name_length = $length;
	# 	}
	# }

	# my $term_width = terminal-width(:default<80>);
	# my $max_description_width = $term_width - ( $max_name_length + 3 );
	# term_width - (max_name_length + " | " )

	my $table = Prettier::Table.new(
		field-names => ['Command', 'Description'],
		align => %('Command' => 'l', 'Description' => 'l')
	);
	for @commands -> %command {
		$table.add-row([%command<name>, %command<description>])
	}
	say $table;

}
my sub extract-usage(%command --> Str){
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
			return $usage_proc.out.slurp(:close).subst(/. \x08 | \x08 /, "", :g);
		}
	}

	return %command<fallback_usage> if %command<fallback_usage>;

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
