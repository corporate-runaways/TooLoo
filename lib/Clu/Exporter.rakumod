# =begin pod
# =head1 Clu::Ingester
# =para
# Ingests a TOML file with information about a command.
#
# =end pod

unit module Clu::Exporter;
use XDG::GuaranteedResources; # to load the md template
use Template6;
use XDG::BaseDirectory;
use Clu::Command;
use Clu::Resourcer; # for the templates
use Clu::Tagger;
use XDG::GuaranteedResources::AbstractResourcer; # just debugging
use DB::SQLite;
use Listicles;
use Prettier::Table;

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
	my $tags_statement_handle = get-tags-for-command-statement-handle($connection);
	my $template = get-md-template();
	export-details-pages(@commands,
						 :$tags_statement_handle,
						 :$template,
						 :$target_directory);

	export-index-page(@commands,
					 :$tags_statement_handle,
					 :$template,
					 :$target_directory);

}

my sub export-index-page(@commands,
						 :$tags_statement_handle,
						 Template6 :$template,
						 :$target_directory) {

	my $index_markdown =  generate-index-markdown(@commands, $template);
	# TODO: make this configurable to work with systems other than hugo
	my $filename = '_index.md';
	persist-file($target_directory, $filename, $index_markdown);
}


my sub export-details-pages(@commands,
							:$tags_statement_handle,
							Template6 :$template,
							:$target_directory
						   ){
	for @commands -> $command_hash {
		my $tags_list = get-tags-for-command($command_hash<id>, $tags_statement_handle);
		$command_hash<tags> = $tags_list;
		$command_hash<has_tags> = ! $tags_list.is-empty;
		my $md = generate-details-markdown($command_hash, $template);
		my $filename = slugify($command_hash<name>) ~ '.md';
		persist-file($target_directory, $filename, $md);
	}

}

my sub persist-file(IO::Path $target_directory, Str $filename, Str $content){
	# my $target_path = IO::Spec::Unix.catpath($target_directory, $filename);
	my $target_path = $target_directory.resolve.Str ~ "/$filename";
	spurt $target_path, $content;
}

my sub generate-index-markdown(@commands, Template6 $template){
	my $table = Prettier::Table.new(
		field-names => ['Command', 'Description'],
		align => %('Command' => 'l', 'Description' => 'l')
	);
	for @commands -> %command {
		# [About]({{< ref "/page/about" >}} "About Us")
		%command<md_link> = "[%command<name>](\{\{< ref %command<name> >\}\})";
		$table.add-row([%command<md_link>, %command<description>]);
	}
	$table.set-style('MARKDOWN');
	my %index_data = 'md_table' => $table.Str, 'timestamp' => Date.today.IO.Str;

	$template.process('markdown_index_template', |%index_data);
}

my sub generate-details-markdown(Associative $command_hash, Template6 $template) {
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
	$template.process('markdown_details_template', |$command_hash);
}
my sub get-md-template(){
	my $bd = XDG::BaseDirectory.new;

	my $t6 = Template6.new;
	$t6.add-path: $bd.config-home.add: 'clu'.Str;
	return $t6;
}

my sub slugify(Str $string){
	$string.subst(/['-'+ | \W+]/, '_', :g).subst(/'_' +/, '_', :g).lc
}
