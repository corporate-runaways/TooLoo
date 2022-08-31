use v6;



=begin pod

=head1 NAME

Clu - blah blah blah

=head1 SYNOPSIS

=begin code :lang<raku>

foo

=end code

=head1 DESCRIPTION

Clu is ...

=head1 AUTHOR

masukomi <masukomi@masukomi.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2022 masukomi

This library is free software; you can redistribute it and/or modify it under the MIT License;

=end pod



# PROBABLE DEPENDENCIES
# Terminal::ANSIColor
# Text::MiscUtils
# Text::MiscUtils::Layout ( tables, columns, etc )
# TOML
# DB::SQLite (search)
# Color
# Test::Output
#

use DB::SQLite;

use Clu::Ingester;


# my $*MAIN-ALLOW-NAMED-ANYWHERE = True
# #= search for a command
# sub MAIN ('search', |terms) {
# 	my $search = Clu::Search.new(terms);
# 	$search.display-results;
# 	if $search.results_count > 0 {
# 		$search.display-options;
# 		my $instruction = $search.request-instruction;
# 		if $instruction  ~~ /(\d+) $<cheats> = "c"?/ {
# 			my $command_name = $search.results[~$0.Int];
# 			~$<cheats>.Bool
# 			  ?? Clu::Cheats.new($command_name)
# 			  || Clu::Details.new($command_name);
# 		}
# 	}
# }

# #= display full details on a command
# sub MAIN ('details', $command_name) {
#	my $db = DB::SQLite.new(filename => "$*HOME/.config/clu/database.db", :readonly)
# 	Clu::Details.new($command_name);
# }

# #= display cheats for a command
# sub MAIN ('cheats', $command_name) {
#	my $db = DB::SQLite.new(filename => "$*HOME/.config/clu/database.db", :readonly)
# 	Clu::Cheats.new($command_name)
# 	# TODO: support interacting with the cheats
# 	# to choose one.
# 	# Then leveraging them as templates with params
# 	# that the user can fill in and have it executed.
# }

sub MAIN('add', Str $path) {
	my $db = DB::SQLite.new(filename => "$*HOME/.config/clu/database.db");
	my $response = ingest-metadata($path, $db);
	$db.finish;
	# should return:
	#   ingested, updated, error
	$response ?? {say ("successfully ingested $path"); exit 0;}
	          !! {say ("problems ingesting $path"); exit 1;}
}

# sub MAIN () {
# 	# output usage and quit
# 	Clu::Details.new('clu');
# 	exit
# }
