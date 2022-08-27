unit class Clu;


=begin pod

=head1 NAME

Clu - blah blah blah

=head1 SYNOPSIS

=begin code :lang<raku>

use Clu;

=end code

=head1 DESCRIPTION

Clu is ...

=head1 AUTHOR

masukomi <masukomi@masukomi.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2022 masukomi

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod



# PROBABLE DEPENDENCIES
# Terminal::ANSIColor
# Text::MiscUtils
# Text::MiscUtils::Layout ( tables )
# TOML

my $*MAIN-ALLOW-NAMED-ANYWHERE = True
#= search for a command
sub MAIN ('search', |terms) {
	my $search = Clu::Search.new(terms);
	$search.display-results;
	if $search.results_count > 0
		$search.display-options;
		my $instruction = $search.request-instruction;
		if $instruction  ~~ /(\d+) $<cheats> = "c"?/ {
			my $command_name = $search.results[~$0.Int];
			~$<cheats>.Bool
			  ?? Clu::Cheats.new($command_name)
			  || Clu::Details.new($command_name);
		}
	
}

#= display full details on a command
sub MAIN ('details', $command_name) {
	Clu::Details.new($command_name);
}

#= display cheats for a command
sub MAIN ('cheats', $command_name) {
	Clu::Cheats.new($command_name)
	# TODO: support interacting with the cheats
	# to choose one.
	# Then leveraging them as templates with params
	# that the user can fill in and have it executed.
}

sub MAIN () {
	# output usage and quit
	Clu::Details.new('clu');
	exit
}
