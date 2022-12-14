# Copyright (C) 2022 Kay Rhodes (a.k.a masukomi)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# YOUR CONTRIBUTIONS, FINANCIAL, OR CODE, TO MAKING THIS A BETTER TOOL
# ARE GREATLY APPRECIATED. SEE https://TooLoo.dev FOR DETAILS


unit module TooLoo::Asciicaster;
use Definitely;
use TooLoo::Command;
use TooLoo::Metadata;
use TooLoo::TerminalUtilities;
use DB::SQLite;


proto add-assciicast(Str $path, |){*}

multi add-asciicast(Str $path, DB::SQLite $sqlite) returns Bool is export {
	add-asciicast($path, $sqlite.db);
}

multi add-asciicast(Str $path, DB::Connection $connection) returns Bool is export {
	my $cleaned_path = expand-tilde($path);
	my $io_path = IO::Path.new($cleaned_path);
	add-asciicast-io($io_path, $connection);
}

our sub add-asciicast-io(IO::Path $io_path, DB::Connection $connection) returns Bool is export {
	#it's presumed the $io_path is an extant location at this point
	return False unless validate-local-path($io_path);

	my $command_name = extract-command-from-path($io_path);

	given find-command-id($command_name, $connection) {
		when $_ ~~ Some {
			return update-command($_.value, $io_path, $connection);
		}
		default {
			note("Can't add asciicast file: \"$command_name\" is not a known command.");
		}
	}

	return False;
}

#| runs your asciicast utility (asciinema) with associated command
our sub demo-asciicast(Str $command_name, DB::SQLite $sqlite) returns Bool is export {
	my $connection = $sqlite.db;
	my $command_data = load-command($command_name, $connection); # from Command
	if $command_data.is-something and $command_data.value<asciicast_url> {
		my $url = $command_data.value<asciicast_url>;
		if validate-local-path(IO::Path.new($url)) {
			given get-metadata-value("asciicaster", $connection) {
				when $_ ~~ Str {
					say("playing with $_");
					shell("$_ " ~ $url);
				}
				default {
					say("playing with asciinema");
					shell("asciinema play " ~ $url);
				}
			}
			return True;
		} else {
			note("This does not appear to be a local url:\n$url");
			return False;
		}
	} else {
		my $note = qq:to/END/;
		No asciicast url was specified for $command_name
		Visit https://asciinema.org/ to learn more about
		recording your terminal sessions.

		Asciinema recordings are stored in asciicast format.
		END
		note($note);
	}
	False

}

my sub validate-local-path(IO::Path $path) returns Bool {
	my $str_path = $path.Str;
	return False if $str_path.match(/^\w+ "://"/) or $str_path.starts-with("//");
	# // is a way of starting urls and telling the browser to use whatever the current
	# protocol is. So, if you have a page served by http and https you can
	# have script tags with  src="//foo/bar.js" and not get errors about protocol
	return False unless $path.extension eq "cast";
	return False unless $path ~~ :r; # exists and is readable
	True
}

my sub extract-command-from-path(IO::Path $path) returns Str {
	# see also the IO::Stem zef package which does exactly this
	$path.extension("").basename
}


my sub update-command(Int $id, IO::Path $path, DB::Connection $connection) returns Bool {
	my $update_sql = q:to/END/;
	UPDATE commands
	SET asciicast_url = ?
	WHERE id = ?
END
    my $statement_handle = $connection.prepare($update_sql);
	$statement_handle.execute([$path.Str, $id]);
	True
}
