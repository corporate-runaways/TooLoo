# Contributing to Clu development

First off, thank you for even considering it. 

## Basic Process
1. fork the repo
2. make some improvements
3. add some tests (see below)
4. make some commits
5. make a PR
  - If you're making UI modifications please include a screenshot in your PR comments.

For bonus points, and faster merges, [give me a heads-up on Mastodon](https://connectified.com/@masukomi) (or [Twitter](https://twitter.com/masukomi) ) and let me know there's something I should look at. 

**Note:**  
If you're thinking of some radical change, or completely new UI / Interaction, we should probably discuss it first, just to make sure it's something I'll be interested in merging, or if maybe you should fork the repo and go your own way with it.

## Testing
Alas, standard Raku unit tests don't work great for a command line client where most of the notable methods are interacting with a database, and dependent upon specific db content being present. As such, I'm relying on [bash_unit](https://github.com/pgrange/bash_unit). 

Once you've installed that, `cd` into the `bash_unit_tests` directory and run 

```
bash_unit ./clu_tests.sh
```

When adding a test note that you _must_ specify `XDG_DATA_HOME`, `XDG_CONFIG_HOME`, or both, depending on what you're testing. There are examples of how to do this in the existing tests.

If your test involves the db you'll need the former. If it involves the template, or some new user configurable thing you've come up with, then you'll need the latter. You'll need both if your test involves both. 
