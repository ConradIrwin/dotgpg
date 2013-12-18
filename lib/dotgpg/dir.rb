class Dotgpg
  class Dir < Pathname

    def key_path(key)
      dotgpg + key.email
    end

    def has_key?(key)
      File.exist? key_path(key)
    end

    def add_key(key)
      File.write key_path(key), key.export(armor: true).to_s
    end

    def remove_key(key)
      File.unlink key_path(key)
    end

    def dotgpg
      self + ".gpg"
    end

    def dotgpg?
      dotgpg.directory?
    end

    def all_encrypted_files(dir=self)
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
  end
end
