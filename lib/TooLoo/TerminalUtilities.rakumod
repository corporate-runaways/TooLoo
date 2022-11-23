unit module TooLoo::TerminalUtilities;
use Color;
use Terminal::ANSIColor;
use Terminal::Width;
use Text::MiscUtils::Layout;

constant %COLORS is export = 'WARNING_FOREGROUND' => Color.new('#ff6e67').rgb.join(','),
							 'WARNING_BACKGROUND' => Color.new('#7f8080').rgb.join(',');

sub remaining-term-width(Str $string)
						returns Int is export {

	terminal-width(:default<80>) - $string.elems;
}

sub wrap-with-indent(Int $indent_width, Str $wrappable) returns Str is export {
	my $wrap_width = terminal-width(:default<80>) - $indent_width;

	my $indent_string = " " x $indent_width;
	text-wrap($wrap_width, $wrappable).join("\n$indent_string");
}

#| converts ~/foo to /Users/home/foo (or your OS's equivalent)
sub expand-tilde(Str $path) returns Str is export {
	$path.subst(/^^ "~"/, $*HOME);
}

#| prompts for input in warning colors
sub prompt-warning(Str $message) returns Str is export {
	prompt(
		colored($message, %COLORS['WARNING_FOREGROUND'] ~ " on_" ~ %COLORS['WARNING_BACKGROUND'] )
	)
}

#| says a message in warning colors
sub say-warning(Str $message) is export {
	say(
		colored($message, %COLORS{'WARNING_FOREGROUND'} ~ " on_" ~ %COLORS{'WARNING_BACKGROUND'} )
	)
}

#| finds a the location of a command via `command -v <command_name>`
our sub find-commands-location(Str $command_name) returns Str is export {
	my $where_proc = run "command", "-v", $command_name, :out, :err;
	my $location   = ($where_proc.exitcode == 0
						?? $where_proc.out.slurp(:close).trim
						!! 'UNKNOWN');
}

#| finds an executable on the PATH & returns the directory it's in
sub find-commands-dir(Str $command_name, Str $fallback='UNKNOWN') returns IO::Path is export {
	my $path = find-commands-location($command_name);
	if $path eq 'UNKNOWN' and $fallback ne 'UNKNOWN' {
		$path = $fallback;
	}

	if $path ne 'UKNOWN' {
		my $io_path = $path.IO;
		return $io_path.dirname.IO if $io_path.e;
		die("Unable to determine correct directory for $command_name");
	} else {
		die("Unable to determine location of $command_name");
	}
}
