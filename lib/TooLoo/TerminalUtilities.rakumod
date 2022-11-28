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
