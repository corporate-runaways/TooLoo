unit module Clu::Asciicaster:ver<1.0.1>:auth<masukomi (masukomi@masukomi.org)>;
use Definitely;
use Clu::Command;
use Clu::Metadata;
use DB::SQLite;


our sub add-asciicast(Str $path, DB::SQLite $db) returns Bool is export {
	my $cleaned_path = $path.subst(/^^ "~"/, $*HOME);
	my $io_path = IO::Path.new($cleaned_path);

	return False unless validate-local-path($io_path);

	my $command_name = extract-command-from-path($io_path);

	given find-command-id($command_name, $db) {
		when $_ ~~ Some {
			return update-command($_.value, $io_path, $db);
		}
		default {
			note("Can't add asciicast file: \"$command_name\" is not a known command.");
		}
	}

	return False;
}

#| runs your asciicast utility (asciinema) with associated command
our sub demo-asciicast(Str $command_name, DB::SQLite $db) returns Bool is export {
	my $command_data = load-command($command_name, $db); # from Command
	if $command_data.is-something and $command_data.value<asciicast_url> {
		my $url = $command_data.value<asciicast_url>;
		if validate-local-path(IO::Path.new($url)) {
			given get-metadata-value("asciicaster", $db) {
				when $_ ~~ Str {
					say("using metadata val: $_");
					shell("$_ " ~ $url);
				}
				default {
					say("Using asciinema");
					shell("asciinema play " ~ $url);
				}
			}
			return True;
		} else {
			note("This does not appear to be a local url:\n$url");
			return False;
		}
	} else {
		note("No asciicast url specified for $command_name");
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


my sub update-command(Int $id, IO::Path $path, DB::SQLite $db) returns Bool {
	my $update_sql = q:to/END/;
	UPDATE commands
	SET asciicast_url = ?
	WHERE id = ?
END
    my $statement_handle = $db.db.prepare($update_sql);
	$statement_handle.execute([$path.Str, $id]);
	True
}
