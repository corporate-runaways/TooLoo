unit module TooLoo::Server;

use TooLoo::Command;
use TooLoo::Metadata;
use Definitely;
use Template6;
use JSON::Fast;
use DB::SQLite;
use HTTP::Status;

our sub serve(Str $host, Int $port, DB::SQLite $sqlite) is export {
	my $quick_conn = $sqlite.db;
	my $tooloo_version = get-tooloo-version($quick_conn);
	$quick_conn.finish;

	react {
		whenever IO::Socket::Async.listen($host, $port) -> $http_conn {
			whenever $http_conn.Supply.lines -> $line {
				# ok, whatcha need boss?
				my @request_stuff = $line.split(/\s+/);
				my %json_data;
				if @request_stuff[0] eq 'GET' {
					my $connection = $sqlite.db;
					given @request_stuff[1] {
						when $_ eq '/' or $_ eq '/list'  {
							%json_data = generate-list-json($connection);
						}
						when $_.match(rx{^ '/show/' ([ \w | '-' ]+) } ) {
							my $command_name = $0.Str;
							%json_data = generate-show-json($command_name, $connection);
						}
						default {
							%json_data = version => $tooloo_version;
							%json_data{'error'}="Unexpected command request: $_";
							%json_data{'status'} = 406; # not acceptable
						}
					}
					$connection.finish;
				} else {
					%json_data = version => $tooloo_version;
					%json_data{'error'}="Only GET requests currently supported";
					%json_data{'status'} = 400; # bad request
				}

				my $json_string = to-json(%json_data);
				$http_conn.print: qq:heredoc/END/;
					HTTP/1.1 { %json_data{'status'} } { HTTP::Status(%json_data{'status'}).title }
					Content-Type: application/json

					$json_string
					END
				$http_conn.close;
			}
		}
		CATCH {
			default {
				warn(.message);
			}
		}
	}

}


proto generate-show-json(Str $command_name, |) returns Associative is export {*}
multi sub generate-show-json(Str $command_name, DB::SQLite $sqlite) returns Associative is export {
	my $connection  = $sqlite.db;
	my $json = generate-show-json($command_name, $connection);
	$connection.finish;
	return $json;
}
multi sub generate-show-json(Str $command_name, DB::SQLite::Connection $connection) returns Associative is export {
	my %json_data = initial-json-data($connection);
	my $maybe_command = load-command($command_name, $connection);
	if $maybe_command ~~ Some {
		my $command_hash = $maybe_command.value;
		$command_hash{'usage'} = extract-command-usage($command_hash);
		$command_hash{'tags'}=get-tags-for-command($command_hash<id>, $connection);
		%json_data{'command'} = $command_hash;
	} else {
		%json_data{'error'} = "Couldn't find command: $command_name";
		%json_data{'status'} = 404; # not found
	}
	return %json_data;
}


#-------
proto generate-list-json(|){*}
multi sub generate-list-json(DB::SQLite $sqlite) returns Associative is export {
	my $connection = $sqlite.db;
	my $json = generate-list-json($connection);
	$connection.finish;
	return $json;
}
multi sub generate-list-json(DB::SQLite::Connection $connection) returns Associative is export {
	my %json_data = initial-json-data($connection);
						   #  vvvv from TooLoo::Command
	%json_data<commands> = get-quick-list($connection);
	return %json_data;
}



#-------
my sub initial-json-data(DB::SQLite::Connection $connection) returns Associative {
	my $tooloo_version = get-tooloo-version($connection);
	return {version => $tooloo_version, status => 200};
}
