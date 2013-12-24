dotgpg is a tool for backing up and versioning your production secrets securely and easily.

Production secrets are things like your cookie encryption keys, database passwords and AWS access keys. All of them have two things in common: your app needs them to runs and no-one else should be able to get to them.

Most people do not look after their production secrets well. If you've got them in your source-code, or unencrypted in Dropbox or Google docs you are betraying your users trust. It's too easy for someone else to get at them.

Dotgpg aims to be as easy to use as your current solution, but with added encryption. It manages a shared directory of GPG-encrypted files that you can check into git or put in Dropbox. When you deploy the secrets to your servers they are decrypted so that your app can boot without intervention.

Getting started
---------------

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
$ dotgpg edit production.env.gpg
[ opens your $EDITOR ]
```

#### dotgpg cat

To read encrypted files, `dotgpg cat` them.

```
$ dotgpg cat prodution.env.gpg
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

## Use without ruby

The only person who really needs to use the `dotgpg` executable is the one responsible for adding and removing users from the directory. If you want to use `dotgpg` without requiring everyone to install ruby you can give them these instructions:

To export your GPG key, use: `gpg --armor --export EMAIL_ADDRESS`. (If you get an error 'nothing exported', you can generate a new key using the default settings of `gpg --gen-key`.)

To read the encrypted files use `gpg --decrypt FILE`.

To edit the encrypted files, you'll want to use [vim-gnupg](https://github.com/jamessan/vim-gnupgnumber) and add `autocmd User GnuPG let b:GPGOptions += ["sign"]` to your `~/.vimrc`. Every time a new user is added to the directory, you'll need to sync GPG's public key store with `gpg --import .gpg/*` or you won't be able to save changes.

## Security

I'm not a security professional, so please [email me](conrad.irwin@gmail.com) if you have feedback on anything in this section.

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

