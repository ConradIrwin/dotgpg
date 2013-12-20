require "./spec/helper"

describe Dotgpg::Dir do
  before do
    @dir = Dotgpg::Dir.new($basic)
  end
  describe "dotgpg?" do
    it 'should be true in a directory managed by dotgpg' do
      assert_equal true, @dir.dotgpg?
    end

    it 'should not be true in a random directory' do
      assert_equal false, Dotgpg::Dir.new(".").dotgpg?
    end

    it "should not be true in a directory that doesn't exist" do
      assert_equal false, Dotgpg::Dir.new(rand.to_s).dotgpg?
    end
  end

  describe "known_keys" do
    before do
      @keys = @dir.known_keys
    end

    it "should return private keys in the truststore" do
      assert_includes @keys, GPGME::Key.find(:secret, "test@example.com").first
    end

    it "should return public keys not yet in the truststore" do
      assert_includes @keys.map(&:email), "test2@example.com"
    end

    it "should return public keys in the truststore" do
      assert_includes @keys.map(&:email), "test2@example.com"
    end
  end

  describe "all_encrypted_files" do
    before do
      @files = @dir.all_encrypted_files
    end

    it "should find files in the top-level" do
      assert_includes @files, $basic + "a"
    end

    it "should find files in sub-directories" do
      assert_includes @files, $basic + "b" + "c"
    end

    it "should not find unencrypted files" do
      readme = $basic + "README.md"
      assert readme.exist?
      refute_includes @files, $basic + "README.md"
    end

    it "should not find files through symlinks" do
      duplicate_a = $basic + "c" + "basic" + "a"
      assert duplicate_a.exist?
      refute_includes @files, duplicate_a
    end
  end

  describe "decrypt" do
    before do
      Dotgpg.passphrase = "test"
    end

    it "should be able to decrypt files for which the secret is known" do
      s = StringIO.new
      @dir.decrypt $basic + "a", s
      s.rewind
      assert_equal "Test\n", s.read
    end

    it "should warn if the file cannot be read" do
      assert_warns "#{$basic + "404"}: No such file or directory" do
        @dir.decrypt $basic + "404", StringIO.new
      end
    end

    it "should warn if the file cannot be decrypted" do
      assert_warns "#{$basic + "README.md"}: No data" do
        @dir.decrypt $basic + "README.md", StringIO.new
      end
    end

    it "should raise on bad passphrase" do
      Dotgpg.passphrase = 'wrong'
      assert_raises GPGME::Error::BadPassphrase do
        assert_warns nil do
          @dir.decrypt $basic + "a", StringIO.new
        end
      end
    end
  end

  describe "encrypt" do
    before do
      Dotgpg.passphrase = 'test'
    end

    it "should armor files" do
      @dir.encrypt $basic + "test-armor", 'test'
      assert_match(/-----BEGIN PGP MESSAGE-----/, File.read($basic + "test-armor"))
    end

    it "should encrypt files to all recipients" do
      @dir.encrypt $basic + "test-recipients", 'test'

      ["D1B8548C844F4881", "54907534D1B5A86B", "8490321363F14C03"].each do |keyid|
        assert_contains_keyid keyid, File.read($basic + "test-recipients")
      end
    end
  end

  describe "add_key" do
    before do
      Dotgpg.passphrase = 'test'
    end

    it "should create the file in the .gpg directory" do
      add1 = Dotgpg.read_key $fixture + "add1.key"
      refute $basic.join(".gpg", "add1@example.com").exist?
      @dir.add_key add1
      assert $basic.join(".gpg", "add1@example.com").exist?
    end

    it "should add the key as a recipient on all the files" do
      add2 = Dotgpg.read_key $fixture + "add2.key"
      refute_contains_keyid add2.subkeys.last.keyid, File.read($basic + "a")
      @dir.add_key add2
      assert_contains_keyid add2.subkeys.last.keyid, File.read($basic + "a")
    end
  end

  describe "remove_key" do
    before do
      Dotgpg.passphrase = 'test'
    end

    it "should remove the file from the .gpg directory" do
      removed1 = Dotgpg.read_key $basic.join(".gpg", "removed1@example.com")
      assert $basic.join(".gpg", "removed1@example.com").exist?
      @dir.remove_key removed1
      refute $basic.join(".gpg", "removed1@example.com").exist?
    end

    it "should remove the key as a recipient from all the files" do
      removed2 = Dotgpg.read_key $basic.join(".gpg", "removed2@example.com")
      assert_contains_keyid removed2.subkeys.last.keyid, File.read($basic + "a")
      @dir.remove_key removed2
      refute_contains_keyid removed2.subkeys.last.keyid, File.read($basic + "a")
    end
  end
end
