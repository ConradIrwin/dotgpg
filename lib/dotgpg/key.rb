class Dotgpg
  class Key

    def self.read(file)
      GPGME::Key.import(file).imports.map do |import|
        GPGME::Key.find(:public, import.fingerprint)
      end.flatten.first
    end

    def self.secret_key(email=nil, force_new=nil)
      new.secret_key(email, force_new)
    end

    def secret_key(email=nil, force_new=nil)
      existing = existing_key(email)
      if existing && !force_new
        existing
      else
        create_new_key email
      end
    end

    private

    def existing_key(email=nil)
      existing_private_keys.detect do |k|
        email.nil? || k.email == email
      end
    end

    def create_new_key(email=nil)
      name = guess_name
      email ||= guess_email

      if email
        puts "Creating a new GPG key: #{name} <#{email}>"
        passphrase = get_passphrase
      else
        puts "Creating a new GPG key for #{name}"
        email = get_email
        passphrase = get_passphrase
      end

      puts "Generating large prime numbers, please wait..."
      ctx = GPGME::Ctx.new
      ctx.genkey(<<EOF, nil, nil)
<GnupgKeyParms format="internal">
Key-Type: RSA
Key-Length: 2048
Subkey-Type: RSA
Subkey-Length: 2048
Name-Real: #{name}
Name-Comment: dotgpg
Name-Email: #{email}
Expire-Date: 0
Passphrase: #{passphrase}
</GnupgKeyParms>
EOF

      # return the most recently created key (race!)
      GPGME::Key.find(:secret).sort_by{ |key|
        key.primary_subkey.timestamp
      }.last
    end

    def guess_name
      name = `git config user.name 2>/dev/null`.strip
      name = `whoami`.strip if name == ""
      name
    end

    def guess_email
      email = `git config user.email 2>/dev/null`.strip
      email if email != ""
    end

    def get_email
      email = ""
      until email =~ /@/
        email = Dotgpg.read_input "Email address: "
      end
      email
    end

    def get_passphrase
      passphrase = confirmation = nil
      until passphrase && passphrase == confirmation
        times = 0
        until passphrase && passphrase.length >= 10
          times += 1
          $stderr.puts "Passphrases should be secure! (>=10 chars)" if times >= 2
          passphrase = Dotgpg.read_passphrase("Passphrase: ")
        end
        until confirmation && confirmation.length >= 10
          confirmation = Dotgpg.read_passphrase("Passphrase confirmation: ")
        end
      end
      passphrase
    end

    def existing_private_keys
      GPGME::Key.find(:secret)
    end
  end
end
