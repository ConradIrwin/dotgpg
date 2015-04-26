dotgpg is a tool for backing up and versioning your [production secrets](#deploying) or [shared passwords](#shared-passwords) securely and easily. ([Why?](#why))

## Getting started

If you're a ruby developer, you know the drill. Either `gem install dotgpg` or add `gem "dotgpg"` to your Gemfile.

There are also instructions for [use without ruby](#use-without-ruby).

#### Mac OS X

1. `brew install gpg`
2. `sudo gem install dotgpg`

#### Ubuntu

1. `sudo apt-get install ruby1.9`
2. `sudo gem install dotgpg`

## Usage

#### dotgpg init

To get started run `dotgpg init`. Unless you've used GPG before, it will prompt you for a new passphrase. You should make this passphrase as [secure as your SSH passphrase](#security), i.e. 12-20 characters and not just letters.

```
$ dotgpg init
Creating a new GPG key: Conrad Irwin <conrad.irwin@gmail.com>
Passphrase:
Passphrase confirmation:
```

#### dotgpg edit

To create or edit files, just use `dotgpg edit`. I recommend you use the `.gpg` suffix so that other tools know what these files contain.

```
$ dotgpg edit production.gpg
[ opens your $EDITOR ]
```

#### dotgpg cat

To read encrypted files, `dotgpg cat` them.

```
$ dotgpg cat prodution.gpg
GPG passphrase for conrad.irwin@gmail.com:
```

#### dotgpg add

To add other people to your team, you need to `dotgpg add` them. To run this command you need their public key (see `dotgpg key`).

```
$ dotgpg add
Paste a public key, then hit <ctrl-d> twice.
<paste>
<ctrl-d><ctrl-d>
```

Once you've added them run `git commit` or let Dropbox work its syncing magic and they'll be able to access the files just like you.

#### dotgpg key

To be added to a dotgpg directory, you just need to send your GPG public key to someone who already has access. Getting the key is as easy as running `dotgpg key`. Then email/IM someone who already has access (you can see the list with `ls .gpg`).

```
$ dotgpg key
-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: GnuPG v1.4.15 (Darwin)

mQENBFK2JfMBCAC8wX7dsWiNX2Ov9akPlz+54Y7n8a3gtdP63CiabW9Ao4614ZDu
vZWI8GIr1QaqMQOcUnhVe9BU3u3y4TX5ei1rHp4ykKoum606R7oFKS5Q4viob/6W
rfVND/o/Sh8twY9ZIpOxRq1zqfGmJk/wSTMuM047hhPUDZVf1BNU+lkURTh2qqnL
...snip...
ZQPcmlBEEI4zq+4GzLTTHHM3/rcHHZmi5p9JAK8OxM/Xyc2otF+N/+iGtIIHjD4a
0FJjy4jQzl7FsvLbDf0VDbcw6RZkJ5dGXIyaEcNiOkF3UGwDcfg6oLsA7d5lo+3a
leJCaaNJQBbIOj4QOjFWiZ8ATqLH9nkgawSwOV3xp0MWayCJ3MVnibt4CaI=
=Vzb6
-----END PGP PUBLIC KEY BLOCK-----
```

#### dotgpg merge

See the 'Integration With Git' section below.

## Why

Production secrets are the keys that your app needs to run. For example the session cookie encryption key, or the database password. These are critical to the running of your app, so it's essential to have a backup that is version controlled. Then if anything goes wrong, you can find the previous values and go back to running happily.

Unfortunately it's also essential that your production secrets are kept secret. This means that traditional solutions to storing them, like putting them unenecrypted in git or in a shared google doc or in Dropbox are not sufficiently secure. Anyone who gets access to your source code, or to someone's Dropbox password, gets the keys to the kingdom for free.

Dotgpg aims to be as easy to use as "just store them in git/Dropbox", but because it uses [gpg encryption](#security) is less vulnerable. If someone gets access to your source code, or someone's Google Apps account, they won't be able to get to your production database.

## Deploying

### dotenv

I recommend using [dotenv](https://github.com/bkeepers/dotenv) for production secrets, then storing your production `.env` file as `config/dotgpg/production.gpg` in your web repository (after doing `dotgpg init config/dotgpg`).

You can do this manually with ssh:

```shell
dotgpg cat config/dotgpg/production.gpg |\
    ssh host1.example.com 'cat > /apps/website/shared/.env'
```

Or use Capistrano's `put` helper:

```ruby
file = `dotgpg cat config/dotgpg/production.gpg`
put file, "/apps/website/shared/.env"
```

### Heroku

We store a dump of `heroku config -s` in `dotgpg` with added comments. The dotgpg version is considered the master version, so if we make a mistake configuring Heroku (I've done that before...) we can restore easily.

### Other

You're kind of on your own for now :). Just store secrets in dotgpg and nowhere else, and you'll be fine!

If you've got a setup that you think is common enough, please send a pull request to add docs.

## Shared passwords

You can also use `dotgpg` to share passwords for things that you log into manually with the rest of your team. This works particularly well if you put the `dotgpg` directory into Dropbox so that it syncs magically.

## Use without ruby

The only person who really needs to use the `dotgpg` executable is the one responsible for adding and removing users from the directory. If you want to use `dotgpg` without requiring everyone to install ruby you can give them these instructions:

To export your GPG key, use: `gpg --armor --export EMAIL_ADDRESS`. (If you get an error 'nothing exported', you can generate a new key using the default settings of `gpg --gen-key`.)

To read the encrypted files use `gpg --decrypt FILE`.

To edit the encrypted files, you'll want to use [vim-gnupg](https://github.com/jamessan/vim-gnupgnumber) and add `autocmd User GnuPG let b:GPGOptions += ["sign"]` to your `~/.vimrc`. Every time a new user is added to the directory, you'll need to sync GPG's public key store with `gpg --import .gpg/*` or you won't be able to save changes.

## Security

I'm not a security professional, so please [email me](mailto:conrad.irwin@gmail.com) if you have feedback on anything in this section.

The files stored in `dotgpg` are unreadable to an attacker provided:

1. A file encrypted by GnuPG cannot be decrypted except by someone with access to a recipient's private key.
2. No-one has access to your GPG private key.

The former assumption is reasonably strong. I'm willing to accept the tiny risk that there's a bug in GnuPG because it'll make headline news.

The latter assumption is reasonably weak. GPG private keys are stored encrypted on your laptop, and the encryption key is based on a passphrase.

This means that if someone gets access to your laptop (or a backup) they can easily get your GPG key unless you've chosen a [secure passphrase](https://howsecureismypassword.net/). I consider this acceptable risk because, by default, SSH passwords are easier to crack than GPG passphrases (GPG uses 65536 rounds of SHA-1 while SSH uses a [single round of MD5](http://martin.kleppmann.com/2013/05/24/improving-security-of-ssh-private-keys.html)) and if they can decrypt your SSH key they can read the secrets directly off your production servers.

### Change passphrase

If you didn't choose a secure passphrase, you can change it with:

```
gpg --edit-keys conrad.irwin@gmail.com passwd
```

If you can't remember your passphrase then you generate a new key with `dotgpg key -n` and ask someone on your team to overwrite your existing key with `dotgpg add -f`.

### Revoking access

Occasionally people leave, or stop needing access to dotgpg. To remove them use `dotgpg rm`.

```
dotgpg rm conrad.irwin@gmail.com
```

### Integration with git

Encrypted files don't work well with many git workflows because they are (basically) binary files that appear to be text files. Because of this diff and merge may appear to work from git's point of view but will actually generate garbage according to GPG. It's possible to work around this:

Add the following lines to your [git config](http://git-scm.com/docs/git-config):
```
[diff "gpg"]
  textconv = dotgpg unsafe_cat
[merge "gpg"]
  name = dotgpg merge driver
  driver = "dotgpg merge %O %A %B"
```
(you may need to use `bundle exec dotgpg ...` depending on how you've installed dotgpg and ruby)

Add the following lines to your [git attributes](http://git-scm.com/book/en/v2/Customizing-Git-Git-Attributes)
```
*.gpg diff=gpg merge=gpg
```

Now `git diff` will show you the diff of the decrypted content. `git merge` will decrypted your files, try to merge the decrypted text, and then encrypt the subsequent output. If there's a conflict the file will be marked as such but will still be a valid GPG file - the decrypted file will contain the text with the merge conflict markers in it.

It's probably possible to adapt this to other VCS's.
