require 'pathname'
require 'fileutils'
require 'tempfile'

require 'gpgme'
require 'thor'

require "dotgpg/key.rb"
require "dotgpg/dir.rb"

class Dotgpg

  def self.read_key(file)
    GPGME::Key.import(file).imports.map do |import|
      GPGME::Key.find(:public, import.fingerprint)
    end.flatten.first
  end

  def self.decrypt(input, output)
    ctx.decrypt GPGME::Data.new(input), GPGME::Data.new(output)
  end

  def self.encrypt(keys, input, output)
    ctx.encrypt keys, GPGME::Data.new(input), GPGME::Data.new(output), GPGME::ENCRYPT_ALWAYS_TRUST
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
      raise error
    end
  end

  class << self
    private

    def passfunc(hook, uid_hint, passphrase_info, prev_was_bad, fd)
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

    def ctx
      @ctx ||= GPGME::Ctx.new(
        armor: true,
        passphrase_callback: method(:passfunc)
      )
    end
  end
end
