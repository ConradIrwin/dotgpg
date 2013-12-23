require 'pathname'
require 'fileutils'
require 'tempfile'
require 'shellwords'

require 'gpgme'
require 'thor'

require "dotgpg/key.rb"
require "dotgpg/dir.rb"
require "dotgpg/cli.rb"

class Dotgpg

  class Failure < RuntimeError; end
  class InvalidSignature < RuntimeError; end

  # This method copied directly from Pry and is
  # Copyright (c) 2013 John Mair (banisterfiend)
  # https://github.com/pry/pry/blob/master/LICENSE
  def self.editor
    configured = ENV["VISUAL"] || ENV["EDITOR"] || guess_editor
    case configured
    when /^mate/, /^subl/
      configured << " -w"
    when /^[gm]vim/
      configured << " --nofork"
    when /^jedit/
      configured << " -wait"
    end

    configured
  end

  def self.guess_editor
    %w(subl sublime-text sensible-editor editor mate nano vim vi open).detect do |editor|
      system("which #{editor} > /dev/null 2>&1")
    end
  end

  def self.read_input(prompt)
    $stderr.print prompt
    $stderr.flush
    $stdin.readline.strip
  end

  def self.read_passphrase(prompt)
    `stty -echo`
    read_input prompt
  ensure
    $stderr.print "\n"
    `stty echo`
  end

  def self.interactive=(bool)
    @interactive = bool
    if interactive?
      # get rid of stack trace on <ctrl-c>
      trap(:INT){ exit 2 }
    else
      trap(:INT, "DEFAULT")
    end
  end

  def self.interactive?
    !!@interactive
  end

  # TODO: it'd be nice not to store the passphrase in
  # plaintext in RAM.
  def self.passphrase=(passphrase)
    @passphrase = passphrase
  end

  def self.warn(context, error)
    if interactive?
      $stderr.puts "#{context}: #{error.message}"
    else
      puts "raising warning"
      raise error
    end
  end

  def self.passfunc(hook, uid_hint, passphrase_info, prev_was_bad, fd)
    if interactive? && (!@passphrase || prev_was_bad != 0)
      uid_hint = $1 if uid_hint =~ /<(.*)>/
      @passphrase = read_passphrase "GPG passphrase for #{uid_hint}: "
    elsif !@passphrase
      raise "You must set Dotgpg.password or Dotgpg.interactive"
    end

    io = IO.for_fd(fd, 'w')
    io.puts(@passphrase)
    io.flush
  end
end
