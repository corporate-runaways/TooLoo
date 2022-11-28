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


#TODO rewrite this to match TooLoo::Command


# use Red:ver<2>;

# model TooLoo::Cheat is table<cheats> {
#     has Int $.id            is serial;
#     has Int $!command_id    is column is rw ;
#     has Str $.description   is column is rw;
#     has Str $.template      is column is rw;

#     has $.command is relationship({ .id }, :model<TooLoo::Command>);
# }

# red-defaults "SQLite", database => '~/.config/clu/database.db'
