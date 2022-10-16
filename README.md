(Command LookUp)

Got an overwhelming number of command line scripts and functions? So many you've actually started to forget what options you have available, or what some of them do? Try Clu!

# What does it do?

Clu allows provides a [full text search](https://en.wikipedia.org/wiki/Full-text_search) of the name, description, and details of your scripts. When a script includes a \"help\" command, Clu will call it and display current usage docs instead of potentially outdated ones from its cache.

Scroll down to see some examples of its output.

## Future looking

The intent is to support [tldr style \"cheats\"](https://tldr.sh/) for your scripts too. The example TOML template below contains commented out cheats if you feel like writing them now, but Clu currently ignores that data.

Being able to arrow through search results and choose one to see the full details of.

# Installation

Clu is written in [Raku](https://www.raku.org/), and uses the [zef](https://github.com/ugexe/zef) package manager for installation.

If you've already got Raku and zef installed then just run:

`zef install Clu`

## Upgrading
The 2.0 change has a different database structure, and now adheres to the XDG Base Directory specification for where it stores things.

So, first step is to run `zef upgrade Clu`

The easiest way to upgrade your data is to just run it again to set up a new empty db in the new location. Then import re-import all your toml files with something like this:

``` bash
find . -name '*.meta.toml' -exec clu add '{}' \; -exec sleep 1 \;
```
The `sleep` is important, to guarantee you don't have database issues with the different processes competing for the file.

## Raku install quick-guide

Use Homebrew to install [Rakudo](https://rakudo.org/). That's the Raku virtual machine. If you install the [Rakudo Star Bundle](https://rakudo.org/star) then [zef](https://github.com/ugexe/zef) will come along for the ride. You can download it from those links, or install it with homebrew.

    brew install rakudo-star

Now, go back and run the `zef install` command above.

# Usage

```
Usage:
  clu -V|--version[=Any] [--verbose[=Any]]
  clu add <path> -- Add & updates documentation of a command with a .toml file, 
                    or an ansiicast demo with a .cast file
  clu demo <command_name> -- play the asciicast demo of the specified command
  clu demos -- List all your commands that have associated asciicast demos
  clu find [<search_strings> ...] -- Execute a full text against documented commands. 
                                     Search terms should be separate arguments.
  clu list -- List all your commands & their quick description
  clu list <filter> -- Lists a filtered subset of commands via filter: 'demos'
  clu remove <command_name> -- Remove a command from the database
  clu show <command_name> -- Display the full details of a specific command
  clu template <destination> -- Generate a blank TOML template at the specified location.
  clu update <path> -- Updates documentation of a command with a .toml file, 
                       or an ansiicast demo with a .cast file

    <path>            Paths must end in .toml or .cast
    <filter>          Currently supported filters: demos
    <command_name>    The name of the executable
```

## Documenting a new Command

The first step is to create a [TOML file](https://toml.io/en/) for each cli tool you wish to document. Clu doesn't care where these live. My advice is to put them alongside your script, so that when you share your script with others, it can go along for the ride, even if they're not using Clu, TOML is still very readable.

Clu doesn't care what the file is named, so long as it ends with `.toml` but personally I've been using the convention of `<command_name>.meta.toml` and putting it in the same directory as the command I'm documenting.

The `template` comand will generate a TOML file for you where you just have to fill in the blanks.

1.  run `clu template path/to/my_command.meta.toml`

For example: If you have a `foo` command you'd make a `foo.meta.toml` file. It doesn't matter if you're documenting an executable or a shell function.

1.  Edit your new TOML file.
2.  run `clu add path/to/my_command.meta.toml`

That's it. If you ever need to update / change the documentation just edit the TOML file and run `clu update <path/to/my_command.meta.toml>`. It'll find the command with the matching name in the database, and replace it.

## Showing a command

`clu show <command_name>` will display the name, description, and usage of the specified command (if found).

Output looks like this:

    ❯ clu show rg-ignores
    rg-ignores : finds files that rg may be using to ignore patterns

    USAGE: rg-ignores <path>

           Use me when rg isn't finding something you expect
           and rg --hidden isn't helping.
           Looks for files that RipGrep will consult
           in order to find patterns to ignore.

           Note: using --hidden --no-ignore is a short term fix

    --------------------
    type: executable
    lang: bash
    location: /Users/masukomi/bin/rg-ignores

    source repo: https://github.com/masukomi/masuconfigs
    source url: https://github.com/masukomi/masuconfigs/blob/master/bin/rg-ignores

## Finding a command

`clu find <search terms>` Don't bother quoting the search terms. Something like `clu find foo bar baz` is fine.

Clu will perform a full text search for your terms on the name, description, and language fields, and display the results.

If you want more details, run `clu show <command name>` for the command you've found.

Output looks like this:

    ❯ clu find find
    rg-ignores          | finds files that rg may be using to ignore patterns
    git-oldest-ancestor | finds the oldest common ancestor between two git treeishes

## Listing all commands

`clu list` will list everything for you. Output looks like
this:

    ❯ clu list
    backtrace_details   | Pairs a backtrace with the corresponding lines of code
    bak                 | bak moves or copies the proffered file to a .back version
    blankless           | converts whitespace-only lines to empty lines.
    color_test          | outputs a smooth gradient band along the RGB spectrum
    git-branch-pr       | Shows or opens the Pull Request for the current branch
    git-oldest-ancestor | finds the oldest common ancestor between two git treeishes
    hr                  | outputs a horizontal rule the width of your terminal
    is_brewed           | indicates if a package is installed via homebrew
    rg-ignores          | finds files that rg may be using to ignore patterns
    watch_when          | Polls a command and reports when its output changes

## Updating a command

`clu update <path/to/my_command.meta.toml>` will find the existing command with the name specified in the TOML and update its data. If you have changed the name of the command you'll need to remove and add instead of update.

## Removing a command

`clu remove <command_name>` will remove the command with the
specified name.

## Syncing between machines

There's no inherent syncing here. Sorry. You can copy the db from `~/.config/clu/database.db` to another machine, or, you can boot it up on a new system and run something like this to ingest all your toml files.

``` bash
find ~/folder/with/my/clu_toml_files -name "*.meta.toml" -exec clu add '{}' \;
```
# Contributing
See [CONTRIBUTING.md](https://github.com/masukomi/Clu/blob/main/CONTRIBUTING.md#readme)
# LICENSE

Copyright 2022 [Kay Rhodes](https://masukomi.org) (a.k.a. masukomi). Distributed under the MIT License.
