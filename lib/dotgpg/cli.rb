class Dotgpg
  class Cli < Thor
    include Thor::Actions

    class_option "help", type: :boolean, desc: "Show help", aliases: ["-h"]

    desc "init [DIRECTORY]", "create a new dotgpg directory"
    option :"new-key", type: :boolean, desc: "Force creating a new key", aliases: ["-n"]
    option :email, type: :string, desc: "Use a specific email address", aliases: ["-e"]
    def init(directory=".")
      return if helped?

      dir = Dotgpg::Dir.new directory

      if dir.dotgpg.exist?
        fail "#{directory}/.gpg already exists"
      end

      key = Dotgpg::Key.secret_key(options[:email], options[:"new-key"])

      info "Initializing new dotgpg directory"
      info "  #{directory}/README.md" unless File.exist? 'README.md'
      info "  #{directory}/.gpg/#{key.email}"

      FileUtils.mkdir_p(dir.dotgpg)
      unless File.exist? 'README.md'      
        FileUtils.cp Pathname.new(__FILE__).dirname.join("template/README.md"), dir.path.join("README.md")
      dir.add_key(key)
      end
    end

    desc "key", "export your GPG public key in a format that `dotgpg add` will understand"
    option :"new-key", type: :boolean, desc: "Force creating a new key", aliases: ["-n"]
    option :email, type: :string, desc: "Use a specific email address", aliases: ["-e"]
    def key
      return if helped?

      key = Dotgpg::Key.secret_key(options[:email], options[:"new-key"])
      $stdout.print key.export(armor: true).to_s
    end

    desc "add [PUBLIC_KEY]", "add a user's public key", aliases: ["-f"]
    option :force, type: :boolean, desc: "Overwrite an existing key with the same email address", aliases: ["-f"]
    def add(file=nil)
      return if helped?

      dir = Dotgpg::Dir.closest
      fail "not in a dotgpg directory" unless dir

      key = read_key_file_for_add(file)
      fail "#{file || "<stdin>"}: not a valid GPG key" unless key

      if dir.has_key?(key) && !options[:force]
        fail "#{dir.key_path(key)}: already exists"
      end

      info "Adding #{key.name} to #{dir.path}"
      info "  #{dir.key_path(key).relative_path_from(dir.path)}"

      dir.add_key(key)
    rescue GPGME::Error::BadPassphrase => e
      fail e.message
    end

    desc "rm KEY", "remove a user's public key"
    option :force, type: :boolean, desc: "Succeed silently if the key doesn't exist or is your own secret key", aliases: ["-f"]
    def rm(file=nil)
      return if helped?(file.nil?)

      dir = Dotgpg::Dir.closest
      fail "not in a dotgpg directory" unless dir

      key = read_key_file_for_rm(file)
      fail "#{file}: not a valid GPG key" if !key && !options[:force]

      if key
        if GPGME::Key.find(:secret).include?(key) && !options[:force]
          fail "#{file}: refusing to remove your own secret key"
        end

        info "Removing #{key.name} from #{dir.path}"
        info "D #{dir.key_path(key).relative_path_from(dir.path)}"
        dir.remove_key(key)
      end
    rescue GPGME::Error::BadPassphrase => e
      fail e.message
    end

    desc "cat FILES...", "decrypt and print files"
    def cat(*files)
      return if helped?

      dir = Dotgpg::Dir.closest(*files)
      fail "not in a dotgpg directory" unless dir

      files.each do |f|
        dir.decrypt f, $stdout
      end
    rescue GPGME::Error::BadPassphrase => e
      fail e.message
    end

    desc "edit FILES...", "edit and re-encrypt files"
    def edit(*files)
      return if helped?

      dir = Dotgpg::Dir.closest(*files)
      fail "not in a dotgpg directory" unless dir

      dir.reencrypt files do |tempfiles|
        if tempfiles.any?
          to_edit = tempfiles.values.map do |temp|
            Shellwords.escape(temp.path)
          end

          system "#{Dotgpg.editor} #{to_edit.join(" ")}"
          fail "Problem with editor. Not saving changes" unless $?.success?
        end
      end

    rescue GPGME::Error::BadPassphrase => e
      fail e.message
    end

    private

    # If the global --help or -h flag is passed, show help.
    #
    # Should be invoked at the start of every command.
    #
    # @param [Boolean] force  force showing help
    # @return [Boolean]  help was shown
    def helped?(force=false)
      if options[:help] || force
        invoke :help, @_invocations[self.class]
        true
      end
    end

    # Print an informational message in interactive mode.
    #
    # @param [String] msg  The message to show
    def info(msg)
      if Dotgpg.interactive?
        $stdout.puts msg
      end
    end

    # Fail with a message.
    #
    # In interactive mode, exits the program with status 1.
    # Otherwise raises a Dotgpg::Failure.
    #
    # @param [String] msg
    def fail(msg)
      if Dotgpg.interactive?
        $stderr.puts msg
        exit 1
      else
        raise Dotgpg::Failure, msg, caller[1]
      end
    end

    # Read a key from a given file or stdin.
    #
    # @param [nil, String]  the file the user specified.
    # @return [nil, GPGME::Key]
    def read_key_file_for_add(file)
      if file.nil?
        if $stdin.tty?
          info "Paste a public key, then hit <ctrl+d> twice."
          key = Dotgpg::Key.read($stdin)
        else
          key = Dotgpg::Key.read($stdin)
          $stdin.reopen "/dev/tty"
        end
      elsif File.readable?(file)
        key = Dotgpg::Key.read(File.read(file))
      end
    end

    # Read a key from a given file or from the .gpg directory
    #
    # @param [String]  the file the user specified
    # @return [nil, GPGME::Key]
    def read_key_file_for_rm(file)
      if !File.exist?(file) && File.exist?(".gpg/" + file)
        file = ".gpg/" + file
      end

      if File.readable?(file)
        Dotgpg::Key.read(File.read(file))
      end
    end
  end
end
