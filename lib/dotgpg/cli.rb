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
      end
      dir.add_key(key)
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

    desc "unsafe_cat FILES...", "unsafely decrypt and print files"
    def unsafe_cat(*files)
      return if helped?
      files.each do |f|
        $stdout.puts Dotgpg.decrypt_without_validating_signatures File.open f
      end
    end

    desc "create FILE DATA", "create an encrypted file with contents DATA"
    def create(file, data)
      return if helped?
      files = [file]
      dir = Dotgpg::Dir.closest(*files)
      fail "not in a dotgpg directory" unless dir

      dir.encrypt file, data

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

    desc "merge MYFILE OLDFILE YOURFILE", "dotgpg-aware wrapper for merging via diff3(1)"
    def merge(*files)
      require 'find'
      require 'digest'
      require 'fileutils'

      return if helped?
      fail "usage: MYFILE OLDFILE YOURFILE" unless files.length == 3

      # ok, we won't know which gpg directory was used for our files because
      # the .merge_files are dumped in the root git dir. so we resort to ulginess
      # - we hash OLDFILE, search for directories which contain a .gpg subdir
      # and check the md5sums of all the files in said directory. if there's a
      # match we have our dir
      old_hash = Digest::SHA256.file(files[1]).hexdigest

      # if file is nil DotGpg:Dir.closest throws an error. if it's just a blank
      # string we get the "not in a dotgpg directory" message
      file = ''

      Find.find(::Dir.pwd) do |path|
        if FileTest.directory?(path) && File.basename(path) == ".gpg"
          # found a .gpg dir, check in the parent for our target file
          dotgpg_dir = File.dirname path
          gpg_files = ::Dir.glob(File.join dotgpg_dir, "*")

          if matched = gpg_files.find { |f| File.file?(f) && old_hash == Digest::SHA256.file(f).hexdigest }
            file = matched
            break
          end
        end
      end

      dir = Dotgpg::Dir.closest(file)
      fail "not in a dotgpg directory" unless dir

      mine = Tempfile.open('mine')
      old = Tempfile.open('old')
      yours = Tempfile.open('yours')

      begin
        # decrypt all three of our files
        dir.decrypt files[0], mine
        dir.decrypt files[1], old
        dir.decrypt files[2], yours

        # flush our io
        mine.flush
        old.flush
        yours.flush

        # TODO - could also use diff3(1) here:
        #
        #   "diff3 -L mine -L old -L yours -m #{mine.path} #{old.path} #{yours.path}"
        #
        # but git merge-file's output is more diff3-ish than diff3's, weird.
        cmd = "git merge-file -L mine -L old -L yours -p %s %s %s  2>/dev/null" %
          [ Shellwords.escape(mine.path), Shellwords.escape(old.path),
            Shellwords.escape(yours.path) ]

        # run our merge
        diff = `#{cmd}`
        conflict = !$?.success?
      ensure
        # close and unlink our tempfiles
        mine.close!
        old.close!
        yours.close!
      end

      # make a new stringio object out of our diff output
      io = StringIO.new diff

      #  create a new tempfile to write our merged file to
      t = Tempfile.open('merged')
      begin
        # encrypt our diff3 output
        dir.encrypt t, io
        t.flush

        # and copy that file back to OLDFILE (aka files[1]) since that's where
        # git expects to find it
        FileUtils.copy t.path, files[1]
      ensure
        t.close!
      end

      # this is important - this exit value is what git uses to decide if there
      # is a conflict or not
      exit (conflict ? 1 : 0)
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
