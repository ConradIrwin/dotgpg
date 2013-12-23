class Dotgpg
  class Dir

    attr_reader :path

    # Find the Dotgpg::Dir that contains the given path.
    #
    # If multiple are given only returns the directory if it contains all
    # paths.
    #
    # If no path is given, find the Dotgpg::Dir that contains the current
    # working directory.
    #
    # @param [*Array<String>] paths
    # @return {nil|[Dotgpg::Dir]}
    def self.closest(path=".", *others)
      path = Pathname.new(File.absolute_path(path)).cleanpath

      result = path.ascend do |parent|
                maybe = Dotgpg::Dir.new(parent)
                break maybe if maybe.dotgpg?
              end

      if others.any? && closest(*others) != result
        nil
      else
        result
      end
    end

    # Open a Dotgpg::Dir
    #
    # @param [String] path  The location of the directory
    def initialize(path)
      @path = Pathname.new(File.absolute_path(path)).cleanpath
    end

    # Get the keys currently associated with this directory.
    #
    # @return [Array<GPGME::Key>]
    def known_keys
      dotgpg.each_child.map do |key_file|
        Dotgpg::Key.read key_file.open
      end
    end

    # Decrypt the contents of path and write to output.
    #
    # The path should be absolute, and may point to outside
    # this directory, though that is not recommended.
    #
    # @param [Pathname] path  The file to decrypt
    # @param [IO] output  The IO to write to
    # @return [Boolean]  false if decryption failed for an understandable reason
    def decrypt(path, output)
      File.open(path) do |f|
        signature = false
        temp = GPGME::Crypto.new.decrypt f, passphrase_callback: Dotgpg.method(:passfunc) do |s|
          signature = s
        end

        unless ENV["DOTGPG_ALLOW_INJECTION_ATTACK"]
          raise InvalidSignature, "file was not signed" unless signature
          raise InvalidSignature, "signature was incorrect" unless signature.valid?
          raise InvalidSignature, "signed by a stranger" unless known_keys.include?(signature.key)
        end

        output.write temp.read
      end
      true
    rescue GPGME::Error::NoData, GPGME::Error::DecryptFailed, SystemCallError => e
      Dotgpg.warn path, e
      false
    end

    # Encrypt the input and write it to the given path.
    #
    # The path should be absolute, and may point to outside
    # this directory, though that is not recommended.
    #
    # @param [Pathname] path  The desired destination
    # @param [IO] input  The IO containing the plaintext
    # @return [Boolean]  false if encryption failed for an understandable reason
    def encrypt(path, input)
      File.open(path, "w") do |f|
        GPGME::Crypto.new.encrypt input, output: f,
            recipients: known_keys,
            armor: true,
            always_trust: true,
            sign: true,
            passphrase_callback: Dotgpg.method(:passfunc),
            signers: known_keys.detect{ |key| GPGME::Key.find(:secret).include?(key) }
      end
      true
    rescue SystemCallError => e
      Dotgpg.warn path, e
      false
    end

    # Re-encrypts a set of files with the currently known keys.
    #
    # If a block is provided, it can be used to edit the files in
    # their temporary un-encrypted state.
    #
    # @param [Array<Pathname>] files  the files to re-encrypt
    # @yieldparam [Hash<Pathname, Tempfile>]  the unencrypted files for each param
    def reencrypt(files, &block)
      tempfiles = {}

      files.uniq.each do |f|
        temp = Tempfile.new([File.basename(f), ".sh"])
        tempfiles[f] = temp
        if File.exist? f
          decrypted =  decrypt f, temp
          tempfiles.delete f unless decrypted
        end
        temp.flush
        temp.close(false)
      end

      yield tempfiles if block_given?

      tempfiles.each_pair do |f, temp|
        temp.open
        temp.seek(0)
        encrypt f, temp
      end

      nil
    ensure
      tempfiles.values.each do |temp|
        temp.close(true)
      end
    end

    # List every GPG-encrypted file in a directory recursively.
    #
    # Assumes the files are armored (non-armored files are hard to detect and
    # dotgpg itself always armors)
    #
    # This is used to decide which files to re-encrypt when adding a user.
    #
    # @param [Pathname] dir
    # @return [Array<Pathname>]
    def all_encrypted_files(dir=path)
      results = []
      dir.each_child do |child|
        if child.directory?
          if !child.symlink? && child != dotgpg
            results += all_encrypted_files(child)
          end
        elsif child.readable?
          if child.read(1024) =~ /-----BEGIN PGP MESSAGE-----/
            results << child
          end
        end
      end

      results
    end

    # Does this directory includea key for the given user yet?
    #
    # @param [GPGME::Key]
    # @return [Boolean]
    def has_key?(key)
      File.exist? key_path(key)
    end

    # Add a given key to the directory
    #
    # Re-encrypts all files to add the new key as a recipient.
    #
    # @param [GPGME::Key]
    def add_key(key)
      reencrypt all_encrypted_files do
        File.write key_path(key), key.export(armor: true).to_s
      end
    end

    # Remove a given key from a directory
    #
    # Re-encrypts all files so that the removed key no-longer has access.
    #
    # @param [GPGME::Key]
    def remove_key(key)
      reencrypt all_encrypted_files do
        key_path(key).unlink
      end
    end

    # The path at which a key should be stored
    #
    # (i.e. .gpg/me@cirw.in)
    #
    # @param [GPGME::Key]
    # @return [Pathname]
    def key_path(key)
      dotgpg + key.email
    end

    # The .gpg directory
    #
    # @return [Pathname]
    def dotgpg
      path + ".gpg"
    end

    # Does the .gpg directory exist?
    #
    # @return [Boolean]
    def dotgpg?
      dotgpg.directory?
    end

    def ==(other)
      Dotgpg::Dir === other && other.path == self.path
    end
  end
end
