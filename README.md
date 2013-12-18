dotgpg is a small wrapper around backing up your dotenv files using gpg encryption.

DotGPG
------

[dotenv](https://github.com/bkeepers/dotenv) is an increasingly popular mechanism for configuring applications in production. The main reason for its popularity is its simplicity: the app reads one file on startup (`./.env`) which populates the global ENV with configuration.

The only problem is that these `dotenv` files literally contain the keys to the kingdom. You don't want to leave them lieing around. Dotgpg is a standard way of encrypting these files so that it's easy to share them and version control them. You can commit the encrypted files into git, or put them in dropbox, depending on your needs.

Installation
------------

dotgpg is packaged as a ruby gem, so either `gem install dotgpg` or add `gem "dotgpg"` to your Gemfile and then `bundle install`.

Usage
-----

First `dotgpg init`. This will create a new dotgpg directory which you can interact with using `dotgpg`. For more detail on the structure of the directory, see below.

If you don't yet have a gpg key for the given email address, dotgpg will create one for you.

Once you've init'd this directory you can use `dotgpg edit production.env` and it will open the given file for editing. When you're done editing, close your text editor and `dotgpg` will re-encrypt the files.

To add a collaborator, you need to get their public-key. This can be done by having them run `dogpgp key`. They can send you this ia email or dropbox, it doesn't have to be kept secure.

You then use `dotgpg add /path/to/key` to add them to the dotgpg directory.

Finally, should you need to revoke someone's access, you can do `dotgpg rm conrad@bugsnag.com` and it will reove their ability to read any further changes to the file (obviously if they till have access to the old encrypted version, they'll still be able to decrypt it.

Advanced
--------

The structure of a dotgpg directory is very simple. The directory contains a `.gpg` directory, which in turn includes the keys for all users. By convention the name of the key file is the user's email address to make it easy to see what's happening. Each file in the directory is then encrypted with every key as a recipient.

If you're a gpg expert, and want more control over which keys are used, you can safely use `gpg --armor --export KEY_ID > .gpg/EMAIL_ADDRESS`
Backup / Sharing
----------------

The folders managed by `dotgpg` contain no unencrypted sensitive information. This means that you can put them in Dropbox, or in your git repository, without worrying. You should commit the `.gpg` directory, as it is necessary to ensure that everyone can read the encrypted files.
