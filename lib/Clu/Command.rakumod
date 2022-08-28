# =begin pod

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

# =defn source repo url

# =end pod

unit module Clu::Command:ver<1.0.0>:auth<masukomi (masukomi@masukomi.org)>;
use Definitely;

sub load(Int $id, DB::SQLite $db) returns Maybe[Hash] {
	given $db.query('select * from foo where x = $x', :2x).hash {
		when $_.elems > 0 {
			something($_);
		}
		default {
			nothing(Maybe[Hash]);
		}
	}
}

sub display(Hash $command) {
	#FINISHME
}
