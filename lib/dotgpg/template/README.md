This directory contains GPG-encrypted files managed by `dotgpg`.

Getting started
---------------

To read files in this directory, send the output of running `dotgpg key` to someone
who has access already. They will be able to run `dotgpg add` on your behalf.

Usage
-----

You can edit any file with `dotgpg edit FILE`, and read any file with `dotgpg cat FILE`.

The edit command looks at the value of `$EDITOR`, the internet will have a tutorial on
how to set this up with your favourite editor.

Details
-------

For more information, please see `dotgpg --help`, or the [README](https://github.com/ConradIrwin/dotgpg).
