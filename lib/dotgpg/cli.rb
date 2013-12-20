class Dotgpg
  class Cli < Thor
    include Thor::Actions

    class_option "help", type: :boolean, desc: "Show help"

    desc "init [DIRECTORY]", "create a new dotgpg directory"
    option :"new-key", type: :boolean, desc: "Force creating a new key", aliases: ["-n"], default: false
    option :email, type: :string, desc: "Use a specific email address", aliases: ["-e"]
    def init(directory=".")
      return if helped?
      self.dir = directory
      key = Dotgpg::Key.secret_key(options[:email], options[:"new-key"])

      empty_directory! ".gpg"
      add_active_key! key
    end

    desc "key", "export your public key"
    option :"new-key", type: :boolean, desc: "Force creating a new key", aliases: ["-n"], default: false
    option :email, type: :string, desc: "Use a specific email address", aliases: ["-e"]
    def key
      return if helped?

      key = Dotgpg::Key.secret_key(options[:email], options[:"new-key"])

      puts key.export(armor: true).to_s
    end

    desc "add [PUBLIC_KEY]", "add a user's public key"
    option :force, type: :boolean, desc: "Overwrite an existing key with the same email address"
    def add(file=nil)

      if file.nil?
        if $stdin.tty?
          $stderr.puts "Waiting for you to paste a public key"
          key = Dotgpg.read_key($stdin)
        else
          key = Dotgpg.read_key($stdin)
          $stdin.reopen "/dev/tty"
        end
      else
        key = Dotgpg.read_key(File.open(file))
      end

      unless key
        say_status "invalid key", file || "STDIN", :red
        exit 1
      end
      add_active_key! key
    end

    desc "rm KEY", "remove a user"
    option :force, type: :boolean, desc: "Ignore removal of keys that don't exist"
    def rm(key)

      key = Dotgpg.read_key(file)

      dir.remove_key(key)
    end

    desc "cat FILES...", "decrypt and print files"
    def cat(*files)
      ensure_dotgpg!

      files.each do |f|
        dir.decrypt f, $stdout
      end
    rescue GPGME::Error::BadPassphrase => e
      $stderr.puts e.message
    end

    desc "edit FILES...", "edit and re-encrypt files"
    def edit(*files)
      ensure_dotgpg!

      dir.reencrypt files do |tempfiles|
        to_edit = tempfiles.values.map do |temp|
          Shellwords.escape(temp.path)
        end

        system "#{ENV["EDITOR"]} #{to_edit.join(" ")}"
        unless $?.success?
          $stderr.puts "Problem with editor. Not saving changes"
          exit 1
        end
      end

    rescue GPGME::Error::BadPassphrase => e
      $stderr.puts e.message
    end

    private

    def dir
      @dir ||= Dotgpg::Dir.new(File.absolute_path(Dir.pwd))
    end

    def dir=(dir)
      @dir = Dotgpg::Dir.new(File.absolute_path(dir))
    end

    def helped?
      if options[:help]
        invoke :help, @_invocations[self.class]
        true
      end
    end

    def empty_directory!(dest)
      full = dir.join(dest)
      if full.exist?
        say_status "already exists", full, :red
        exit 1
      end
      say_status "creating", full
      FileUtils.mkdir_p(full)
    end

    def add_active_key!(key)
      ensure_dotgpg!
      if dir.has_key?(key)
        say_status "already exists", dir.key_path(key), :red
        exit 1
      end

      say_status "adding", dir.key_path(key)
      dir.add_key(key)
    end

    def ensure_dotgpg!
      unless dir.dotgpg?
        say_status "no such directory", dir.dotgpg, :red
        puts "You may want to run `dotgpg init` to create it."
        exit 1
      end
    end
  end
end
