# Upgrading from V1.x to V2.x

If you never used Clu (TooLoo's old name) you can ignore these.

For my lovely early adopters. My apologies, and a promise that future major version bumps will be handled as automatically as possible. V2 now has a toolooe what version you're running, and thus should be able to handle upgrades automatically.


## What's changed & How to deal
### What's changed
- New database tables. 
- New database columns.
- New things in the TOML
- New name
- Database is now stored under `XDG_DATA_HOME`

### How to deal
- tweak your TOML as noted below. 
- run the new `add-many` command to 

### TOML Changes

#### Descriptions
I've added `short_description`. It's what `description` used to be. Now `description` is optional, and when present, expected to be a more detailed thing.

Quick fix: Run this in the root directory above all your tooloo description files. It'll change `description` to `short_description` in all your files.

```shell

find . -name '*.meta.toml' -exec perl -pi -e 's/^description *= */short_description=/' '{}' \;
```

Then, when you have time, go in and add longer description entries.

#### TOML File names
The default is now `<command>.toml` However, TooLoo really doesn't care what you call it, or where it lives, so long as it ends with `.toml` and has the expected format.

If you want to rename yours you can run something like this (bash). Note that if you've got them in version control 
you might want to change the `mv` to `git mv`, or whatever's appropriate.

```shell
for f in $(find . -name "*.meta.toml"); do 
	mv $f $(echo $f | sed -e "s/\.meta//"); 
done
```


#### Tags
They're a thing now. 

Your TOML files can intooloode a `tags=["foo", "bar"]` line. Tags are intoolooded in the full text search with stemming, so no need to worry if you tagged it "app" or "apps".

Completely optional, go ahead and add them when you have time.

### Database Changes
It's moved, and it's got a bunch of new stuff. Best solution is to just delete yours. It should be at `~/.config/tooloo/database.db`

It'll be regenerated at `$XDG_DATA_HOME/tooloo/database.db` If `XDG_DATA_HOME` isn't set it'll usually default to `~/.local`.

Once you've updated your TOML files (see above) you run the fancy new 
mass ingestion command to repopulate your db.

```shell
tooloo add-many <starting_directory>
```
