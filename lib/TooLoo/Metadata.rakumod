unit module TooLoo::Metadata;
use DB::SQLite;
use Definitely;


our sub get-metadata-value(Str $key, DB::Connection $connection) returns Maybe[Str] is export {
	my $val = $connection.query('SELECT value from metadata where key=$key', key => $key).value;
	if $val {
		something($val);
	} else {
		nothing(Str);
	}
}

our sub get-tooloo-version(DB::Connection $connection) returns Str is export {
	my $tooloo_version = get-metadata-value("version", $connection);
	return $tooloo_version ~~ Some ?? $tooloo_version.value !! "UNKNOWN";
}

#TODO add set-metadata-value(Str $key, Str $value)
