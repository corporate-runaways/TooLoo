unit module Clu::Tagger;
use Definitely;
use Clu::Command;
use Clu::Metadata;
use DB::Connection;
use Listicles;
use DB::SQLite::Statement;

my sub find-tag-records(@tags, DB::Connection $connection) returns Seq {
	return [].Seq if @tags.is-empty;

	my $tags_list = "'" ~ @tags.join("', '") ~ "'";
	my $search_sql = qq:to/END/;
		SELECT * FROM tags WHERE
		tag in ($tags_list)
		ORDER BY tag ASC;
	END
	# my $tags_list = "'" ~ @tags.join("', '") ~ "'";

	# my $result  = $connection.query($search_sql, $tags_list) ;
	my $result  = $connection.query($search_sql) ;
	return $result.arrays;
}

# - takes a list of tags, adds the new ones
# - returns Seq of tag + id lists
#  $(((2, "debugging"), (1, "ruby")).Seq
my sub add-tags(@tags, DB::Connection $connection) returns Seq {

	# for @tags -> $tag {
	# 	$connection.execute("INSERT INTO tags (tag) VALUES ('$tag')");
	# 	# my $tag_id =  $connection.query("select id from tags where tag = '$tag'; ").value;
	# }



	my @known_tags = find-tag-records(@tags, $connection);
	my @extant_tag_names = @known_tags.map({.[1]});
	# NOTE: that's not a backslash below. It's a "SET MINUS" (\u002216)
	my @new_tags = @tags.Set ∖ @extant_tag_names; # Seq of Pairs
	if ! @new_tags.is-empty {
		my $insert_sql = q:to/END/;
			INSERT INTO TAGS (tag) VALUES
		END

		for (1..@new_tags.elems) {
			$insert_sql ~= " ( ? ),";
		}
		# trim off the last comma
		$insert_sql = substr($insert_sql, 0, *-1);


		# it's a sequence of Pairs, we need an Array of Strings
		my $new_tag_strings = @new_tags.map(*.key).Array;

		my $statement_handle = $connection.prepare($insert_sql);
		my $rows_changed = $statement_handle.execute(|$new_tag_strings);

	}
	return find-tag-records(@tags, $connection);
}

#| Severs the associations between a command and its tags (if any).
my sub delete-commands-tags(Int $command_id, DB::Connection $connection) is export returns Int {
    # my $count = $connection.query("select count(*) from commands_tags where command_id = $command_id").value;
	# if $count > 0 {
		my $delete_sql = "DELETE from commands_tags where command_id = ?";
		my $statement_handle = $connection.prepare($delete_sql);
		return $statement_handle.execute($command_id);
	# }
	# return 0;
}

#| record a list of new/updated tags for the specified command
our sub set-tags-for-command(Int $command_id, @tags, DB::Connection $connection) is export returns Bool {


	my $deleted_connections_count = delete-commands-tags($command_id, $connection);
	my $ids_and_tags = add-tags(@tags.cache, $connection).cache;

	# return early if there's nothing new to inserts
	return True if $ids_and_tags.Seq.is-empty;

	my $insert_sql = 'INSERT INTO commands_tags (command_id, tag_id) VALUES ';

	# these are just IDs, that WE retrieved,
	# so i'm not worried about SQL injection
	for $ids_and_tags.Array -> $tag_tuple {
		$insert_sql ~= " ( $command_id, $tag_tuple[0] ),";
	}
	$insert_sql = substr($insert_sql, 0, *-1);
	$connection.query($insert_sql);

	True
}

proto get-tags-for-command(Int $command_id, |) is export returns Array {*}

multi get-tags-for-command(Int $command_id, DB::Connection $connection) is export returns Array {
	my $sth = get-tags-for-command-statement-handle($connection);
	get-tags-for-command($command_id, $sth)
}

multi get-tags-for-command(Int $command_id, DB::SQLite::Statement $statement_handle) is export returns Array {
	$statement_handle
						 .execute($command_id)
						 .arrays
						 .flatten
						 .Array;

}
our sub get-tags-for-command-statement-handle(DB::Connection $connection) is export returns DB::SQLite::Statement {
	my $tags_search_sql = q:to/END/;
		select tag from commands_tags ct
		inner join tags t on ct.tag_id = t.id
		where command_id = ?;
	END
	my $tags_statement_handle = $connection.prepare($tags_search_sql);
}
