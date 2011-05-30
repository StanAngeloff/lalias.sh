lalias.sh
=========

**lalias** is [Zsh][zsh] shell extension that allows you to have
directory-specific command aliases. It is intended as a development tool.

The original idea was to allow locally installed [Node.js][node] modules to
be used without having to put them on `$PATH`.

Usage
-----

To use this script, source it in your `~/.zshrc` file. For each directory
you want to have aliases available in, create an `.aliases` file and add
each command on a separate line:

    say=echo
    jake=./app/node_modules/.bin/jake  # ./ is relative to the .aliases file

__NOTE__: you can only use commands that don't have a binding yet, e.g., if
you have a `jake` binary on path, it will be executed. This script only runs
for commands that are not found.

[zsh]: http://www.zsh.org/
[node]: http://nodejs.org

### Copyright

> Copyright (c) 2011 Stan Angeloff. See [LICENSE.md](https://github.com/StanAngeloff/lalias/blob/master/LICENSE.md) for details.
