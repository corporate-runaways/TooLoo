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


unit module TooLoo::Metadata;
use DB::SQLite;
use Definitely;


our sub get-metadata-value(Str $key, DB::Connection $connection) returns Maybe[Str] is export {
	my $val = $connection.query('SELECT value from metadata where key=$key', key => $key).value;
	if $val {
		something($val);
	} else {
		nothing(Str);
	}
}

our sub get-tooloo-version(DB::Connection $connection) returns Str is export {
	my $tooloo_version = get-metadata-value("version", $connection);
	return $tooloo_version ~~ Some ?? $tooloo_version.value !! "UNKNOWN";
}

#TODO add set-metadata-value(Str $key, Str $value)
