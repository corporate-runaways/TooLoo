# =begin pod
# =head1 Clu::Ingester
# =para
# Ingests a TOML file with information about a command.
#
# =end pod

unit module Clu::Exporter;
use XDG::GuaranteedResources; # to load the md template
use Template::Mustache;
# use Terminal::ANSIColor;
# use Text::MiscUtils::Layout;
# use Clu::TerminalUtilities;
use Clu::Command;
use Clu::Resourcer; # for the templates
use XDG::GuaranteedResources::AbstractResourcer; # just debugging
# use Clu::Tagger;
# use Color;
use DB::SQLite;
use Listicles;
# use TOML;

our sub export-markdown(IO::Path $target_directory, DB::SQLite $sqlite) returns Bool is export {
	# re target_directory:
	# * ~ has already been expanded
	# * presence has already been validated

	# Prep the queries
	my $search_sql = q:to/END/;
		select * from commands order by name ASC
	END

	my $tags_search_sql = q:to/END/;
		select tag from commands_tags ct
		inner join tags t on ct.tag_id = t.id
		where command_id = ?;
	END

	# Collect the data
	my $connection = $sqlite.db;
	my @commands = $connection.query($search_sql).hashes;
	# becaues the SQL would be complicated, and brute force is
	# still going to be ridiculously fast, we're just going to
	# query for tags for each command individually.
	my $tags_statement_handle = $connection.prepare($tags_search_sql);
	my $template = get-md-template();
	export-details-pages(@commands,
						 :$tags_statement_handle,
						 :$template,
						 :$target_directory);

}

my sub export-details-pages(@commands,
							:$tags_statement_handle,
							:$template,
							:$target_directory
						   ){
	for @commands -> $command_hash {
		$command_hash<tags> = $tags_statement_handle.execute($command_hash<id>).arrays;
		note("\nXXX \$command_hash<tags>: " ~ $command_hash<tags>.raku);
		my $md = generate-markdown($command_hash, $template);
		my $filename = slugify($command_hash<name>) ~ '.md';
		persist-file($target_directory, $filename, $md);
	}

}

my sub persist-file(IO::Path $target_directory, Str $filename, Str $content){
	# my $target_path = IO::Spec::Unix.catpath($target_directory, $filename);
	my $target_path = $target_directory.resolve.Str ~ "/$filename";
	spurt $target_path, $content;
}

my sub generate-markdown(Associative $command_hash, Str $template) {
	$command_hash<safename> = slugify($command_hash<name>);
	$command_hash<usage> = extract-command-usage($command_hash);
	my $asciicast_url = $command_hash<asciicast_url>;
	if $asciicast_url {
		$command_hash<asciicast> = True;
		if ! ! $asciicast_url.match(/'http' 's'* '://'/) {
			$command_hash<asciicast_web_url> = $asciicast_url;
			$command_hash<asciicast_url>:delete;
		}
	} else {
		$command_hash<asciicast> = False;
	}
	Template::Mustache.render($template, $command_hash);
}
my sub get-md-template(){
	my $md_template_resource_path = 'config/clu/markdown_details_template.mustache';
	my $markdown_template_file = guarantee-resource($md_template_resource_path,
												   Clu::Resourcer,
												   debug => True);
	$markdown_template_file.IO.slurp;
}

my sub slugify(Str $string){
	$string.subst(/['-'+ | \W+]/, '_', :g).subst(/'_' +/, '_', :g).lc
}
