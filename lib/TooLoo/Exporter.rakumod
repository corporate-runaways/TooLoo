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


# =begin pod
# =head1 TooLoo::Ingester
# =para
# Ingests a TOML file with information about a command.
#
# =end pod

unit module TooLoo::Exporter;
use TooLoo::Command;
use TooLoo::Resourcer; # for the templates
use DB::SQLite;
use Listicles;
use Prettier::Table;
use Template6;
use XDG::BaseDirectory;
use XDG::GuaranteedResources;
use TooLoo::Resourcer;
use Definitely;

#| Exports markdown files for Hugo. See README for details
our sub export-hugo(IO::Path $target_directory, DB::SQLite $sqlite) returns Bool is export {
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
	say("Export complete.");

}

my sub export-index-page(@commands,
						 :$tags_statement_handle,
						 Template6 :$template,
						 :$target_directory) {

	say("Generating Table of Contents...");
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
	my $maybe_asciicast_dir = find-asciicasts-dir($target_directory);
	if $maybe_asciicast_dir ~~ None {
		note("Couldn't find asciicasts dir. Won't copy over asciicast files.");
	}

	for @commands -> $command_hash {
		say("Generating page for $command_hash<name>...");
		my $tags_list = get-tags-for-command($command_hash<id>, $tags_statement_handle);
		$command_hash<tags> = $tags_list;
		$command_hash<has_tags> = ! $tags_list.is-empty;
		$command_hash<safename> = slugify($command_hash<name>);
		add-asciicast-details($command_hash);
		my $md = generate-details-markdown($command_hash, $template);
		my $filename = slugify($command_hash<name>) ~ '.md';
		persist-file($target_directory, $filename, $md);
		if $maybe_asciicast_dir ~~ Some {
			copy-asciicast($command_hash, $maybe_asciicast_dir.value);
		}
	}

}

my sub copy-asciicast(Associative $command_hash, IO::Path $target_directory) {
	# check if it has asciicast_url
	# if so, it's a local one it will.
	# if it's a web one it will have asciicast_web_url instead
	if $command_hash<asciicast_url> {
		my $io_path = IO::Path.new($command_hash<asciicast_url>);
		if $io_path.e {
			# copy /path/to/foo.cast to (/path/to/asciicasts/ + foo.cast)
			my $destination = $target_directory.add($io_path.basename);
			copy($io_path, $destination);
			say("Copied $io_path to $destination");
		} else {
			note("Couldn't find $command_hash<asciicast_url> locally");
		}
	}
}
my sub find-asciicasts-dir(IO::Path $target_directory) returns Maybe[IO::Path] {
	my $basename = $target_directory.basename;
	# vvv a fancy way of testing if we've reached the root dir
	# that should work on windows too where
	# the root is "C:/" or "D:/" or... whatever
	if $basename ne $target_directory.parent {
		if $basename eq 'content' {
			# excellent. "static" is a sibling of "content" in hugo
			return something($target_directory.parent.add("static/asciicasts"));
		} else {
			return find-asciicasts-dir($target_directory.parent);
		}
	} else {
		return nothing(IO::Path);
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
		%command<md_link> = '['
								~ %command<name>
								~ ']({{< ref '
								~ slugify( %command<name> )
								~ ' >}})';
		$table.add-row([%command<md_link>,  md-escaped(%command<short_description>)]);
	}
	$table.set-style('MARKDOWN');
	my %index_data = 'md_table' => $table.Str, 'timestamp' => Date.today.IO.Str;

	$template.process('markdown_index_template', |%index_data);
}

my sub add-asciicast-details(Associative $command_hash){
	my $asciicast_url = $command_hash<asciicast_url>;
	if $asciicast_url {
		$command_hash<asciicast> = True;
		if ! ! $asciicast_url.match(/'http' 's'* '://'/) {
			$command_hash<asciicast_web_url> = $asciicast_url;
			$command_hash<asciicast_url>:delete;
		} else {
			$command_hash<asciicast_filename> = 	$command_hash<asciicast_url>.IO.basename;
		}
	} else {
		$command_hash<asciicast> = False;
	}
	
}
my sub generate-details-markdown(Associative $command_hash, Template6 $template) {
	$command_hash<usage> = extract-command-usage($command_hash);
	# remove leading and trailing whitespace as they screw with md formatting
	$command_hash<short_description> = md-escaped($command_hash<short_description>.trim);
	$template.process('markdown_details_template', |$command_hash);
}
my sub get-md-template(){
	my $index_path = "config/tooloo/markdown_index_template.tt";
	my $details_path = "config/tooloo/markdown_details_template.tt";
	my @paths = guarantee-resources([ $index_path, $details_path], TooLoo::Resourcer);

	my $t6 = Template6.new;
	$t6.add-path: @paths.first.IO.dirname;
	return $t6;
}

my sub slugify(Str $string){
	$string.subst(/['-'+ | \W+]/, '_', :g).subst(/'_' +/, '_', :g).lc
}

my sub md-escaped(Str $string) returns Str {
	$string.subst(/('_' | '*')/, {'\\' ~ $0}, :g)
}
