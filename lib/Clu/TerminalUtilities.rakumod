unit module Clu::TerminalUtilities;
use Terminal::Width;
use Text::MiscUtils::Layout;
use Color;

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
