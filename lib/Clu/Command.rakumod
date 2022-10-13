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

multi sub display-command(Str $command_name, DB::SQLite $db) is export {
	my $command_data = load-command($command_name, $db);
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
}

multi sub display-command(%command) is export {
# sub display-command(Hash:D %command) is export {
    #TODO: improve coloring
	display-name-and-description(%command);
	display-usage(%command);
	display-metadata(%command);

}

our sub find-commands(Str $search_string, DB::SQLite $db) returns Maybe[Array] {
	my $search_sql = q:to/END/;
	SELECT * FROM commands_fts WHERE
	  name MATCH ?
	  OR description MATCH ?
	  OR language MATCH ?
	ORDER BY rank;
	END

	my @results = $db.query($search_sql, [$search_string, $search_string, $search_string]).hashes ;
	if @results.elems > 0 {
		return something(@results);
	} else {
		return nothing(Array);
	}
}

our sub find-command-id(Str $command_name, DB::SQLite $db) returns Maybe[Int] is export {
	my $val = $db.query('SELECT id FROM commands WHERE name=$name', name => $command_name).value;
	$val ~~ Int ?? something($val) !! nothing(Int);
}
our sub load-command(Str $command_name, DB::SQLite $db) returns Maybe[Hash] {
	given $db.query('select * from commands where name = ?', $command_name).hash {
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

our sub search-and-display(Str $search_string, DB::SQLite $db) is export {
	my $results_maybe = find-commands($search_string, $db);
	if $results_maybe !~~ Some {
		say("No matches found");
	    return;
	}
	my @results = $results_maybe.value[];
	display-names-and-descriptions(@results);
}
