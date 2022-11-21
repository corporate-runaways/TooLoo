# Upgrading from V1.x to V2.x

If you've started on v2.x you can ignore these.

For my lovely early adopters. My apologies, and a promise that future major version bumps will be handled as automatically as possible. V2 now has a clue what version you're running, and thus should be able to handle upgrades automatically.


## What's changed & How to deal
New db tables. New db columns.

### TOML Changes

#### Descriptions
I've added `short_description`. It's what `description` used to be. Now `description` is optional, and when present, expected to be a more detailed thing.

Quick fix: Run this in the root directory above all your clu description files. 

```shell
find . -name '*.meta.toml' -exec perl -pi -e 's/^description *= */short_description=/' '{}' \;
```

Then, when you have time, go in and add longer description entries.

#### Tags
They're a thing now. 

Your TOML files can include a `tags=["foo", "bar"]` line. Tags are included in the full text search with stemming, so no need to worry if you tagged it "app" or "apps".

Completely optional, go ahead and add them when you have time.

### Database Changes
It's moved, and it's got a bunch of new stuff. Best solution is to just delete yours. It should be at `~/.config/clu/database.db`

It'll be regenerated at `$XDG_DATA_HOME/clu/database.db` If `XDG_DATA_HOME` isn't set it'll usually default to `~/.local`.

Once you've updated your TOML files (see above) you can `cd` to the directory with your documentation and run this to repopulate your database.

```shell
find . -name '*.meta.toml' -exec clu add '{}' \; -exec sleep 0.5 \; 
```

The `sleep` is required to deal with some DB locking issues. 
