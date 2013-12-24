dotgpg is a tool for backing up and versioning your production secrets securely and easily.

Production secrets are things like your cookie encryption keys, database passwords, AWS access keys. All of them have two things in common: your app needs them to run, no-one else should be able to get to them.

Most people do not look after their production secrets well. If you've got them in your source-code, or unencrypted in Dropbox or Google docs you are betraying your users trust. It's too easy for someone else to get at them.

Dotgpg aims to be as easy to use as your current solution, but with added encryption. It provides on a shared directory of GPG-encrypted files that you can check into git, or put in Dropbox. When you deploy the secrets to your servers, they are decrypted so that your app can boot without intervention.

Getting started
---------------

If you're a ruby developer, you know the drill. Either `gem install dotgpg` or add `gem "dotgpg"` to your Gemfile.

There are also instructions for [use without ruby](#use-without-ruby).

### Mac OS X

1. `brew install gpg`
2. `sudo gem install dotgpg`

### Ubuntu

1. `sudo apt-get install ruby1.9`
2. `sudo gem install dotgpg`

## Usage

To get started run `dotgpg init`. Unless you've used GPG before, it will prompt you for a new passphrase. You should make this passphrase as [secure as your SSH passphrase](#Security), i.e. 12-20 characters and not just letters.

```
$ dotgpg init
Creating a new GPG key: Conrad Irwin <conrad.irwin@gmail.com>
Passphrase:
Passphrase confirmation:
```

You can now start creating files. For example if you're using dotenv, you might want to create `production.env.gpg`.

```
$ dotgpg edit production.env.gpg
[ opens your $EDITOR ]
```

Reading these files is even easier:

```
$ dotgpg cat prodution.env.gpg
GPG passphrase for conrad.irwin@gmail.com:
```

### Sharing dotgpg

To add other people on your team to `dotgpg`, they first need to run `dotgpg key` to get a public key. It'll look something like this:

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

They then send you this key, and you run:

```
$ dotgpg add
Paste a public key, then hit <ctrl-d> twice.
<paste>
<ctrl-d><ctrl-d>
```

Finally you need to send them the new version of the directory. So either commit it to version control or wait for Dropbox to work its syncing magic. (Or send them a tarball if you're really old-school)

## Use without ruby.

The only person who really needs to use the `dotgpg` executable is the one responsible for adding and removing users from the directory. If you want to use `dotgpg` without requiring everyone to install ruby you can give them these instructions:

To export your GPG key, use: `gpg --armor --export EMAIL_ADDRESS` (instead of `dotgpg key`)

To generate a new key, use: `gpg --gen-key` and accept the defaults (you need to do this if the export step tells you 'nothing exported').

To read the encrypted files use `gpg --decrypt FILE` (instead of `dotgpg cat`)

To edit the encrypted files, you'll want to use [vim-gnupg](https://github.com/jamessan/vim-gnupgnumber) and add `set g:GPGPreferSign=1` to your `~/.vimrc`. Every time a new user is added to the directory, you'll need to sync GPG's public key store with `gpg --import .gpg/*` or you won't be able to save changes.

The two commands I'd recommend you don't try to emulate without `dotgpg` are `dotgpg add` and `dotgpg rm`. These two commands are responsible for maintaining the invariant that each file is encrypted with the same set of public keys that are in the `.gpg` directory. Importantly just adding a public key to this directory will not let them decrypt the files, everything needs to be re-encrypted.

## Why?

Prodution keys are the crown-jewels of any website. With them an attacker can get into your database, send email authenticated as you, forge session cookies for your users. In short, if you loose your keys, you are totally and utterly screwed.

Yet, a lot of people store the keys inline in the code (rails does this by default, which is frankly ridiculous), or in a shared google doc.

The reason for this is that there's no "one way to do it". Hopefully `dotgpg` will become that way.

I've been using this system for about 3-years (since I started at Rapportive, and now am at Bugsnag) without the wrapper script. It works very well in the main, because GPG is excellent. The main problem is that GPG is too hard to use, and requires too much setup. Dotgpg tries to paper over most of the rough edges by automatically importing keys from a shared directorygg

## Security

I am not a security professional, but I've taken a number of steps to help ensure that `dotgpg` is not going to reveal your secrets to anyone if you use a *strong passphrase*.

The security comes from the fragmentation of information. In order to get at the encrypted secrets, the attacker needs:
1. Access to the dotgpg directory (i.e. they need to hack into your Github, or Dropbox, or get your laptop)
2. Access to your encrypted private key (i.e. they need to hack into your backups, or get your laptop)
3. Access to your passphrase (i.e. they need to guess it, find it in a dump of leaked passwords, or find where you wrote it down).

The weakest link in the chain is that if an attacker gets your laptop they only have to guess your passphrase. You must make this secure. By default GPG uses 65536 rounds of SHA-1 to derive a secret that's used to decrypt your passphrase. This will slow down brute forcers a tiny bit (a dedicated attacked can probably do billions of SHA-1 calculations a second) but you should obviously still choose a secure password.

Alternatively they could break the encryption scheme implemented by GnuPG, but if an attacker has the ability to do that, you should be far more worried about your SSH endpoints than your GPG key. That said, you should obviously still be careful. I wouldn't publish your dotgpg dir deliberately, and definitely don't put your encrypted private key anywhere public.

If you think I'm wrong about anything in this section, please [email me](conrad.irwin@gmail.com).

### Change password

If you didn't choose a secure password, you can change it with:

```
gpg --edit-keys conrad.irwin@gmail.com passwd
```
