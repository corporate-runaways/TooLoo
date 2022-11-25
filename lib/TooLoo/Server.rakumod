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
	my $tooloo_version = get-metadata-value("version", $quick_conn);
	$quick_conn.finish;

	$tooloo_version = $tooloo_version ~~ Some ?? $tooloo_version.value !! "1.x";


	react {
		whenever IO::Socket::Async.listen($host, $port) -> $http_conn {
			whenever $http_conn.Supply.lines -> $line {
				# ok, whatcha need boss?
				my @request_stuff = $line.split(/\s+/);
				my %json_data = version => $tooloo_version, status => 200;
				if @request_stuff[0] eq 'GET' {
					my $connection = $sqlite.db;
					given @request_stuff[1] {
						when * eq '/' {
													# from TooLoo::Command
							%json_data{'commands'} = get-quick-list($connection);
						}
						when $_.match(rx{^ '/show/' ([ \w | '-' ]+) } ) {
							my $maybe_command = load-command($0.Str, $connection);
							if $maybe_command ~~ Some {
								my $command_hash = $maybe_command.value;
								$command_hash{'usage'} = extract-command-usage($command_hash);
								%json_data{'command'} = $command_hash;
							} else {
								%json_data{'error'} = "Couldn't find command: $0";
								%json_data{'status'} = 404; # not found
							}
						}
						default {
							%json_data{'error'}="Unexpected command request: $_";
							%json_data{'status'} = 406; # not acceptable
						}
					}
					$connection.finish;
				} else {
					%json_data{'error'}="Only GET requests currently supported";
					%json_data{'status'} = 400; # bad request
				}

				my $json_string = to-json(%json_data);
				$http_conn.print: qq:heredoc/END/;
					HTTP/1.1 { %json_data{'status'} } { HTTP::Status(%json_data{'status'}).title }
					Content-Type: application/json; charset=UTF-8
					Content-Encoding: UTF-8

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
