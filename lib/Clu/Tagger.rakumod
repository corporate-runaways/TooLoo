unit module Clu::Tagger;
use Definitely;
use Clu::Command;
use Clu::Metadata;
use DB::SQLite;
use Listicles;

my sub find-tag-records(@tags, DB::SQLite $db) returns Seq {
	return [] if @tags.is-empty;

	my $tags_list = "'" ~ @tags.join("', '") ~ "'";
	my $search_sql = qq:to/END/;
		SELECT * FROM tags WHERE
		tag in ($tags_list)
		ORDER BY tag ASC;
	END
	# my $tags_list = "'" ~ @tags.join("', '") ~ "'";

	# my $result  = $db.query($search_sql, $tags_list) ;
	my $result  = $db.query($search_sql) ;
	return $result.arrays;
}

# - takes a list of tags, adds the new ones
# - returns Seq of tag + id lists
#  $(((2, "debugging"), (1, "ruby")).Seq
my sub add-tags(@tags, DB::SQLite $db) returns Seq {

	my @known_tags = find-tag-records(@tags, $db);
	my @extant_tag_names = @known_tags.map({.[1]});
	# NOTE: that's not a backslash below. It's a "SET MINUS" (\u002216)
	my @new_tags = @tags.Set ∖ @extant_tag_names;
	note("\nXXX extant_tag_names: " ~ @extant_tag_names.raku);
	note("\nXXX adding new_tags: " ~ @new_tags.raku);
	if ! @new_tags.is-empty {
		my $insert_sql = q:to/END/;
			INSERT INTO TAGS (tag) VALUES (?);
		END

		# efficient? no not really
		# easy? yup.
		# fast enough? yup.
		# $db.db.begin;
		my $statement_handle = $db.db.prepare($insert_sql);
		for @new_tags -> $tag {
			my $clean_tag =  $tag ~~ Pair ?? $tag.key !! $tag;
			note("\nXXX clean_tag: " ~ $clean_tag.raku);
			$statement_handle.execute($clean_tag);
		}
		# $db.db.commit;
		# $statement_handle.finish();
		return find-tag-records(@tags, $db);
	}
	[].Seq
}

#| Severs the associations between a command and its tags (if any).
my sub delete-commands-tags(Int $command_id, DB::SQLite $sqlite) is export returns Int {
    my $count = $sqlite.query("select count(*) from commands_tags where command_id = $command_id").value;
	# NOTE: There's a bug in DB::SQLite if you execute a command that would normally
	# affect rows (insert, update, delete) but NO rows are affected
	# it will lock the db on you. So, you can't just delete regardless of if there are any.
	if $count > 0 {
		my $delete_sql = "DELETE from commands_tags where command_id = ?";
		my $db = $sqlite.db;
		my $statement_handle = $db.prepare($delete_sql);
		return $statement_handle.execute($command_id);
	}
	return 0;
}

#| record a list of new/updated tags for the specified command
our sub set-tags-for-command(Int $command_id, @tags, DB::SQLite $sqlite) is export returns Bool {


	# - takes a command_id and a list of tags
	# vvv BREAKS
	# my $new_tags = add-tags(@tags.cache, $sqlite).List.first;

	# BEGIN HACK
	# 		vvv WORKS
	        for @tags -> $tag {
				$sqlite.execute("INSERT INTO tags (tag) VALUES ('$tag')");
				my $tag_id =  $sqlite.query("select id from tags where tag = '$tag'; ").value;

		    # vvv BREAKS
			# for $new_tags -> $tag_pair {
				# $sqlite.execute("INSERT INTO tags (tag) VALUES ('$tag')");
				# my $tag_id =  $sqlite.query("select id from tags where tag = '$tag'; ").value;
				# note("\nXXX: \$tag_pair: " ~ $tag_pair.gist ~ " or " ~ $tag_pair.raku);
				# my $tag_id = $tag_pair.first;

            # vvv works
				$sqlite.execute("INSERT INTO commands_tags (command_id, tag_id) values ($command_id, $tag_id)");

				# $statement_handle.execute([$command_id, $tag_id]);
			}
			return True;
			my $new_tags = Seq.new;
	# END HACK


	# - delete any tags currently associated with it
	#   the inefficiency is less "expensive" than the maintenance
	#   of the more complex code that'd be required to find and delete
	#   ones that're no longer valid.
	my $deleted_count = delete-commands-tags($command_id, $sqlite);
	# - creates rows in commands_tags
	if $new_tags.Array.elems > 0 {
		note("\nXXX: \$new_tags: " ~ $new_tags.raku);
		# my $insert_sql = q:to/END/;
		# INSERT INTO commands_tags (command_id, tag_id)
		# VALUES( ?, ? )
		# END
		my $db = $sqlite.db;
		# my $statement_handle = $db.prepare($insert_sql);
		# $db.begin;
		my $count = $db.query("select count(*) from commands_tags where command_id = $command_id  ").value;
		# $db.commit;
		note("\nXXX: commands_tags count for $command_id: $count");
		for $new_tags.Array -> $tag_array {
			my $tag_id = $tag_array[0];
			$db.execute("INSERT INTO commands_tags (command_id, tag_id) values ($command_id, $tag_id)");
			# $statement_handle.execute([$command_id, $tag_id]);
		}
		# $db.commit;
		# $statement_handle.finish();
	}
	True
}
