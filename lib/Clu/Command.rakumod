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

unit module Clu::Command:ver<1.0.0>:auth<masukomi (masukomi@masukomi.org)>;
use Definitely;
use Terminal::ANSIColor;
use Text::MiscUtils::Layout;
use Clu::TerminalUtilities;
use Color;
use DB::SQLite;

my sub load-command(Int $id, DB::SQLite $db) returns Maybe[Hash] {
	given $db.query('select * from foo where x = $x', :2x).hash {
		when $_.elems > 0 {
			something($_);
		}
		default {
			nothing(Maybe[Hash]);
		}
	}
}

my sub display-command(%command) is export {
# sub display-command(Hash:D %command) is export {
    #TODO: improve coloring
	display-name-and-description(%command);
	display-usage(%command);
	display-metadata(%command);

}

#FIXME
my sub display-metadata(%command) {
# sub ansi-display-metadata(Hash %command) {
	say "-" x 4;

	say "type: " ~ (%command.EXISTS-KEY("type") ?? %command<type> !! "UNKNOWN");
	say "lang: " ~ (%command.EXISTS-KEY("language")
					?? %command<language>
					!! "UNKNOWN");
	# my $where_proc = run "where", %command<name>, :out, :err;
	# say "location: " ~ $where_proc.exitcode == Nil
	# 					?? $where_proc.out.slurp(:close)
	# 					!! %command<location>
	# 						?? %command<location>
	# 						!! "UNKNOWN";
}
my sub display-name-and-description(%command) {
# sub ansi-display-name-and-description(Hash %command) {
	my $separator = ' : ';
	my $wrapped_desc = wrap-with-indent(
		(%command<name>.elems + $separator.elems),
		%command<description>
       );

    say colored("%command<name>" ~ $separator ~ "$wrapped_desc\n", "black on_white" );
}

my sub display-usage(%command) {
# sub ansi-display-usage(Hash %command) {
	if %command<usage_command> {
		# prints to STDOUT and/or STDERR
		run split(/\s+/, %command<usage_command>);
	} elsif %command<fallback_usage> {
		say %command<fallback_usage>;
	} else {
		say colored("USAGE UNKNOWN",
					"{%COLORS<WARNING_FOREGROUND>} on_{%COLORS<WARINING_BACKGROUND>}");
	}
}
