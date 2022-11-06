unit module Clu::Metadata;
use DB::SQLite;
use Definitely;


our sub get-metadata-value(Str $key, DB::Connection $connection) returns Maybe[Str] is export {
	my $val = $connection.query('SELECT value from clu_metadata where key=$key', key => $key).value;
	if $val {
		something($val);
	} else {
		nothing(Str);
	}
}

#TODO add set-metadata-value(Str $key, Str $value)
