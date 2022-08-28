unit class Clu::Search;

# TODO: restrict @terms to Array[Str]
multi method new(@terms) returns Array[Hash] {

}

=begin pod
in order to search we need data on /all/
the commands


we /could/ search in known dirs and load them
all into memory, but that would take time, and
give us crappy search.
=end pod
