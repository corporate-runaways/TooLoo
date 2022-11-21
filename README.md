# TooLoo

Got an overwhelming number of command line scripts and functions? So
many you\'ve actually started to forget what options you have available,
or what some of them do? Try TooLoo!

# What does it do?

TooLoo allows provides a [full text
search](https://en.wikipedia.org/wiki/Full-text_search) of the name,
description, and details of your scripts. When a script includes a
\"help\" command, TooLoo will call it and display current usage docs
instead of potentially outdated ones from its cache.

Scroll down to see some examples of its output.

Additionally, TooLoo can generate a static web site with a built-in
[Lunr](https://lunrjs.com/) search to document all your commands. To
accomplish this, TooLoo generates the Markdown files, and
[Hugo](https://gohugo.io/) builds the search index, and converts it to a
site for you.

# Installation

TooLoo is written in [Raku](https://www.raku.org/), and uses the
[zef](https://github.com/ugexe/zef) package manager for installation.

If you\'ve already got Raku and zef installed then just run:

`zef install TooLoo`

If you don\'t have Raku installed then...

## Raku install quick-guide

Use Homebrew to install [Rakudo](https://rakudo.org/). That\'s the Raku
virtual machine. If you install the [Rakudo Star
Bundle](https://rakudo.org/star) then
[zef](https://github.com/ugexe/zef) will come along for the ride. You
can download it from those links, or install it with homebrew.

``` example
brew install rakudo-star
```

Now, go back and run the `zef install` command above.

## Upgrading

See the `1_to_2_upgrade.md` file

# Usage

``` example
Usage:
  tooloo -V|--version[=Any] [--verbose[=Any]]
  tooloo add <path> -- Add & updates documentation of a command with a .toml file, or an ansiicast demo with a .cast file
  tooloo demo <command_name> -- play the asciicast demo of the specified command
  tooloo demos -- List all your commands that have associated asciicast demos
  tooloo find [<search_strings> ...] -- Execute a full text against documented commands. Search terms should be separate arguments.
  tooloo list -- List all your commands & their quick description
  tooloo list <filter> -- Lists a filtered subset of commands via filter: 'demos'
  tooloo export <format> <directory> -- Create a static blog documenting all your commands
  tooloo remove <command_name> -- Remove a command from the database
  tooloo show <command_name> -- Display the full details of a specific command
  tooloo template <destination> -- Generate a blank TOML template at the specified location.
  tooloo update <path> -- Updates documentation of a command with a .toml file, or an ansiicast demo with a .cast file

    <path>            Paths must end in .toml or .cast
    <filter>          Currently supported filters: demos
    <format>          Currently supported formats: hugo
    <directory>       the directory to export to
    <command_name>    The name of the executable
```

## Documenting a new Command

The first step is to create a [TOML file](https://toml.io/en/) for each
cli tool you wish to document. TooLoo doesn\'t care where these live. My
advice is to put them alongside your script, so that when you share your
script with others, it can go along for the ride, even if they\'re not
using TooLoo, TOML is still very readable.

TooLoo doesn\'t care what the file is named, so long as it ends with
`.toml` but personally I\'ve been using the convention of
`<command_name>.meta.toml` and putting it in the same
directory as the command I\'m documenting.

The `template` comand will generate a TOML file for you so
that you just have to fill in the blanks.

1.  run `tooloo template path/to/my_command.meta.toml`

For example: If you have a `foo` command you\'d make a
`foo.meta.toml` file. It doesn\'t matter if you\'re
documenting an executable or a shell function.

1.  Edit your new TOML file.
2.  run `tooloo add path/to/my_command.meta.toml`

That\'s it. If you ever need to update / change the documentation just
edit the TOML file and run
`tooloo update <path/to/my_command.meta.toml>`. It\'ll find
the command with the matching name in the database, and replace it.

### Documentation Details

The comments in the generated template should be enough to document your
command, but here are some additional notes.

Whenever there\'s a list `short_description` will be used.
Depending on your personal usage `description` may not be
worth it. However, if you\'re exporting and generating a static web site
from tooloo you\'ll definitely want that.

The Usage section of each command is generated on the fly whenever
possible. Some commands don\'t have a `--help` option or
anything similar, in which case you\'ll need to fill in the
`fallback_usage`. When doing so, be sure to not use any tabs.
They\'ll muck with the table that\'s displayed.

## Showing a command

`tooloo show <command_name>` will display the name,
description, and usage of the specified command (if found).

Output looks like this:

![](https://raw.githubusercontent.com/masukomi/Clu/readme_images/images/show.png "a two column table listing attributes of the command and their associated details")

## Demoing a command

If you\'ve recorded a demo of the command in the asciicast format you
can associated that file with the command, and have TooLoo run the demo
for you. This requires [asciinema](https://asciinema.org/) to be
installed locally.

    tooloo demo <command-with-demo>

To see all the commands that have associated asciicasts you can simply
ask TooLoo to list all the demos.

    tooloo demos

## Finding a command

`tooloo find <search terms>` Don\'t bother quoting the search
terms. Something like `tooloo find foo bar baz` is fine.

TooLoo will perform a full text search for your terms on the name,
description, and language fields, and display the results.

If you want more details, run `tooloo show <command name>`
(see below) for the command you\'ve found.

Output looks like this:

![](https://raw.githubusercontent.com/masukomi/Clu/readme_images/images/find.png "a two column table listing the found commands and short descriptions")

## Listing all commands

`tooloo list` will list everything for you. Output looks like
this:

![](https://raw.githubusercontent.com/masukomi/Clu/readme_images/images/list.png "a two column table listing commands and short descriptions")

As noted above, you can get a list of all the commands with asciinema /
asciicast demos by running `tooloo list demos` or just
`tooloo demos`.

## Updating a command

`tooloo update <path/to/my_command.meta.toml>` will find the
existing command with the name specified in the TOML and update its
data. If you have changed the name of the command you\'ll need to remove
and add instead of update.

## Removing a command

`tooloo remove <command_name>` will remove the command with
the specified name.

## Syncing between machines

There\'s no inherent syncing here. Sorry. You can copy the db from
`~/.config/tooloo/database.db` to another machine, or, you
can boot it up on a new system and run something like this to ingest all
your toml files.

``` {.bash org-language="sh"}
find ~/folder/with/my/tooloo_toml_files -name "*.meta.toml" -exec tooloo add '{}' \;
```

## Generating a Static Blog

TooLoo can export Markdown files in order to generate a static blog.
Right now it\'s expecting that you\'ll be using
[Hugo](https://gohugo.io/) along with our [default site
structure](https://github.com/masukomi/tooloo_blank_hugo_site), or more
likely, some beautifully tweaked variant of it.

A demo of the default site structure and theme is available at
[demo.tooloo.dev](https://demo.tooloo.dev)

To generate your blog run
`tooloo export hugo ~/path/to/tooloo_blank_hugo_site/content/all_commands`
The theme has a concept of \"chapters\" and \"all~commands~\" is the
first \"chapter\". You can, of course, change this. It\'s ultimately a
variation of the [Hugo Learn
Theme](https://github.com/matcornic/hugo-theme-learn) which has [good
documentation](https://learn.netlify.app/).

# Why is it called \"TooLoo\"?

1.  It\'s short for \"Tool Lookup\": Too(l) Loo(kup) -\> TooLoo
2.  It\'s fun to say.
3.  The .dev domain was available.
4.  The original name was likely to be misspelled.
5.  It allows me to accommodate future features documenting more than
    just command line things.

# Contributing

See
[CONTRIBUTING.md](https://github.com/masukomi/TooLoo/blob/main/CONTRIBUTING.md#readme)

# LICENSE

Copyright 2022 [Kay Rhodes](https://masukomi.org) (a.k.a. masukomi).
Distributed under the GPL 3.0 License.
