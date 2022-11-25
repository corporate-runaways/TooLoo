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
  tooloo add <file_path> -- Add & updates documentation of a command with a .toml file, or an ansiicast demo with a .cast file
  tooloo add-many <directory_path> -- Add / update all .toml & .cast files in a directory or its children.
  tooloo demo <command_name> -- play the asciicast demo of the specified command
  tooloo demos -- List all your commands that have associated asciicast demos
  tooloo find [<search_strings> ...] -- Execute a full text against documented commands. Search terms should be separate arguments.
  tooloo list -- List all your commands & their quick description
  tooloo list <filter> -- Lists a filtered subset of commands via filter: 'demos'
  tooloo export <format> <export_directory> -- Create a static blog documenting all your commands
  tooloo remove <command_name> -- Remove a command from the database
  tooloo show <command_name> -- Display the full details of a specific command
  tooloo template <command_name> -- Generate a blank TOML template alongside the specified command
  tooloo update <path> -- Updates documentation of a command with a .toml file, or an ansiicast demo with a .cast file

    <file_path>           Paths must end in .toml or .cast
    <directory_path>      Path to dir to search for .toml & .cast files
    <filter>              Currently supported filters: demos
    <format>              Currently supported formats: hugo
    <export_directory>    the directory to export to
    <command_name>        The name of the executable
```

## Documenting a new Command

The first step is to create a [TOML file](https://toml.io/en/) for each
cli tool you wish to document.

Ask TooLoo to generate a blank template for you with

`tooloo <command>`

TooLoo will create a new file named `<command>.toml` in the
same directory as the command. If it can\'t find the command, or that
directory isn\'t writable it\'ll ask you were to put the new file.

TooLoo doesn\'t care where your TOML files live. Keeping them in the
same directory as the command is just an easy way to help guarantee they
get updated when the command does, and get moved too if you decide to
move the command. That way, even if your teammates aren\'t using TooLoo
they\'ll have some additional documentation they can read.

Once you have generated the new file, edit it, fill in the details, and
tell TooLoo to add it with `tooloo add path/to/command.toml`

That\'s it. If you ever need to update / change the documentation just
edit the TOML file and run
`tooloo update <path/to/my_command.toml>`. It\'ll find the
command with the matching name in the database, and update the docs.

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

### Customizing The Template

The first time you call `tooloo template` a copy of the
default template will be placed in your
`XDG_CONFIG_HOME/toolo/template.toml` From then on that file
will be used.

Feel free to open that up, and add or remove any comments you want. If
you add additional fields they will be ignored by TooLoo.

Note: `XDG_CONFIG_HOME` defaults to `~/.config` on
most systems.

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

`tooloo update <path/to/my_command.toml>` will find the
existing command with the name specified in the TOML and update its
data. If you have changed the name of the command you\'ll need to remove
and add instead of update.

## Removing a command

`tooloo remove <command_name>` will remove the command with
the specified name.

## Syncing between machines (mass ingestion) {#syncing-between-machines}

There\'s no inherent syncing here. Sorry. You can copy the db from
`~/.config/tooloo/database.db` to another machine, or, you
can boot it up on a new system and run the command for mass-ingestion.

    tooloo add-many /path/to/dir/with/toml/files

TooLoo will look for all the `.toml` and `.cast`
files in that directory and its subdirectory, and install everything
that it finds, which seems to be valid.

Note, if it attempts to load a `.cast` file before the
corresponding `.toml` file has been loaded you\'ll get a
warning about the command not existing. You can either
`tooloo add path/to/cast_file` or rerun `add-many`
again.

If you still get the warning it means that it\'s time to go find, or
create, a TOML file for that command, and `add` it.

## Generating a Static Blog

TooLoo can export Markdown files in order to generate a static blog.
Right now it\'s expecting that you\'ll be using
[Hugo](https://gohugo.io/) along with our [default site
structure](https://github.com/masukomi/tooloo_blank_hugo_site), or more
likely, some beautifully tweaked variant of it.

A demo of the default site structure and theme is available at
[demo.tooloo.dev](https://demo.tooloo.dev)

Assuming you\'re using our default site structure, you\'ll execute the
following to generate your files:

    tooloo export hugo ~/path/to/tooloo_blank_hugo_site/content/all_commands

Note that we\'re telling it to store the files in the
`all_commands` directory.

The theme has a concept of \"chapters\" and \"all~commands~\" is the
first \"chapter\". You can, of course, change this. It\'s ultimately a
variation of the [Hugo Learn
Theme](https://github.com/matcornic/hugo-theme-learn) which has [good
documentation](https://learn.netlify.app/).

Note: by default we symlink `content/_index.md` to
`content/all_commands/_index.md` so that the home page for
the site, is the same as the index for the chapter.

You will probably want to replace that symlink with a real
`_index.md` that describes your collection of tools and gives
readers an idea what they\'re looking at.

### Customizing Generated Markdown

The first time you run `tooloo export` two Markdown templates
will be created in `XDG_CONFIG_HOME/toolo/` They are
`markdown_index_template.tt` and
`markdown_details_template.tt`

The `markdown_index_template.tt` is used to customize the
main page with the table that links to all the other commands. It\'s the
Markdown equivalent of `tooloo list`

The `markdown_details_template.tt` documents the individual
commands. It\'s the markdown equivalent of
`tooloo show <some_command>`

The files use the
[Template6](https://github.com/raku-community-modules/Template6)
templating language which is based on [Perl 5\'s Template
Toolkit](http://template-toolkit.org/). The Template6 docs are fairly
thin right now, but Template Toolkit is *well* documented and should
answer any questions you may have.

Note 1: `XDG_CONFIG_HOME` defaults to `~/.config`
on most systems.

1.  Available Data

    The following keys are available to the template engine.

    1.  markdown~indextemplate~.tt

        -   \"md~table~\"
            -   a GitHub Flavored Markdown version of the table you see
                when you run `tooloo list`
        -   \"timestamp\"
            -   a simple date stamp: \"2022-11-24\"

    2.  markdown~detailstemplate~.tt

        The keys available to this template correspond to the keys in
        your TOML. Technically it\'s the columns of the
        `commands` table in the database after ingestion.

        In addition:

        -   \"safename\"
            -   the command name with all the non-word characters and
                hyphens replaced with underscores (max 1 per
                substitution) and everything lowercased. So if your
                command name was `foo-Bar!*whee` then
                \"safename\" would contain `foo_bar_whee`
        -   \"usage\"
            -   this will contain the same usage string you\'d see when
                you run `tooloo show <command>`
        -   \"short~description~\"
            -   the same `short_description` as in your TOML
                but with any leading or trailing whitespace removed.
        -   \"asciicast~url~\" has some special notes.
            -   If it is populated there will be an
                `asciicast` key with a `True`
                value.
            -   If it is not populated there will be an
                `asciicast` key with a False value.
            -   If it appears to be a web URL (something starting with
                `http` or `https`) an additional
                key named `asciicast_web_url` will be added
                and `asciicast_url` will be removed.
            -   If it is populated and does not appear to be a web URL
                it will be left untouched.

# Miscellany

## Contributing

See
[CONTRIBUTING.md](https://github.com/masukomi/TooLoo/blob/main/CONTRIBUTING.md#readme)

## LICENSE

Copyright 2022 [Kay Rhodes](https://masukomi.org) (a.k.a. masukomi).
Distributed under the GPL 3.0 License.

## Why is it called \"TooLoo\"?

1.  It\'s short for \"Tool Lookup\": Too(l) Loo(kup) -\> TooLoo
2.  It\'s fun to say.
3.  The .dev domain was available.
4.  The original name was likely to be misspelled.
5.  It allows us to accommodate future features documenting more than
    just command line things.
