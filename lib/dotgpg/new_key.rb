class Dotgpg
  class Key

    def self.new
      super.key
    end

    attr_reader :key

    def initialize
      ctx = GPGME::Ctx.new()

      puts "Creating a gpg key for use with dotgpg"
      name = get_name
      email = get_email
      puts "Please create a passphrase for the key '#{name}' (#{comment}) <#{email}>."
      puts "Like an SSH passphrase, this should be long and secure."
      passphrase = passphrase

      name
      email
      puts "Creating a new GPG key for #{name} (#{comment}) <#{email}>"
      passphrase

      puts "Generating key. This may take a few seconds..."
      key = ctx.genkey(gnupg_key_parms, nil, nil)
      require 'pry'
      binding.pry
      puts "done!"

    end

    def get_name
      name = `git config --global user.email 2>/dev/null`.strip
      name = `whoami`.strip if name == ""
    end

    def name
      @name ||=(
        return @name = from_git if from_git != ""
        loop do
          print "Email address: "
          name = $stdin.gets.strip
          break name if name.length > 1
        end
      )
    end

    def comment
      "dotgpg " + Time.now.strftime("%Y-%m-%d")
    end

    def email
      @email ||=(
        from_git = `git config --global user.email 2>/dev/null`.strip
        return @email = from_git if from_git =~ /@/
        loop do
          print "Email address: "
          email = $stdin.gets.strip
          break email if email =~ /@/
          puts "Email addresses should have an @ sign. Please try again."
        end
      )
    end

    def passphrase
      @passphrase ||=(
        loop do
          passphrase = loop do
            passphrase = Dotgpg.get_passphrase "Passphrase: "
            break passphrase if passphrase.length > 3
            puts "Passphrases should be long and secure. Please try again."
          end
          check = Dotgpg.get_passphrase "Confirm: "
          break passphrase if passphrase == check
          puts "Confirmation did not match. Please try again."
        end
      )
    end

    def gnupg_key_parms
      <<EOF
<GnupgKeyParms format="internal">
Key-Type: RSA
Key-Length: 2048
Subkey-Type: RSA
Subkey-Length: 2048
Name-Real: #{name}
Name-Comment: #{comment}
Name-Email: #{email}
Expire-Date: 0
Passphrase: #{passphrase}
</GnupgKeyParms>
EOF
    end
  end
end
