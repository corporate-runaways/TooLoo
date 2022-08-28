#TODO rewrite this to match Clu::Command


# use Red:ver<2>;

# model Clu::Cheat is table<cheats> {
#     has Int $.id            is serial;
#     has Int $!command_id    is column is rw ;
#     has Str $.description   is column is rw;
#     has Str $.template      is column is rw;

#     has $.command is relationship({ .id }, :model<Clu::Command>);
# }

# red-defaults "SQLite", database => '~/.config/clu/database.db'
