unit module TooLoo::Templatizer;
use TooLoo::TerminalUtilities;
use Color;

our sub get-template-dir(Str $command_name) returns IO::Path is export {
	my $cd = find-commands-dir($command_name); #either works or dies
	return $cd;
	CATCH {
		default {
			warn(.message);
			say-warning(.message);
			return request-writable-dir();
		}
	}
}
my sub acquire_writable_dir(IO::Path $dir) returns IO::Path {
	# confirm it IS a dir
	# confirm it's writable
	my $writable_dir = is-good-dir($dir)
						?? $dir
						!! request-writable-dir(False) ;

	return $writable_dir;
}

my sub request-writable-dir(Bool $from_bad_dir = False) returns IO::Path {
	say-warning("I can't write to that directory.") if $from_bad_dir;
	my $potential = expand-tilde(prompt("Please enter the path to a writable directory: "));
	my $io_potential = $potential.IO;
	# if it's not a dir, or not a dir we can write to...
	if ! is-good-dir($io_potential) {
		return request-writable-dir(True);
	}
	$io_potential;
}

my sub is-good-dir(IO::Path $dir) returns Bool {
	$dir.d and $dir.w;
}
