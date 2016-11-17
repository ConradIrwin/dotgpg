require "./spec/helper"

describe Dotgpg::Cli do
  before do
    @dotgpg = Dotgpg::Cli.new
  end

  describe "init" do
    it "should default to the current directory" do
      $fixture.join("create-0").mkdir
      Dir.chdir $fixture.join("create-0") do
        @dotgpg.invoke(:init, [])
        assert $fixture.join("create-0", ".gpg", "test@example.com").exist?
      end
    end

    it "should create a .gpg directory" do
      refute $fixture.join("create-1", ".gpg").exist?
      @dotgpg.invoke(:init, [($fixture + "create-1").to_s])
      assert $fixture.join("create-1", ".gpg").exist?
    end

    it "should add the user's secret key to the .gpg directory" do
      @dotgpg.invoke(:init, [($fixture + "create-2").to_s])
      assert_equal $fixture.join("create-2", ".gpg", "test@example.com").read, GPGME::Key.find(:secret).first.export(armor: true).to_s
    end

    it "should add a README to the directory" do
      @dotgpg.invoke(:init, [($fixture + "create-3").to_s])
      assert_equal $fixture.join("create-3", ".gpg", "test@example.com").read, GPGME::Key.find(:secret).first.export(armor: true).to_s
    end

    it "should not add a README if there is already one" do |variable|
      FileUtils.touch 'README.md'
      assert_not_equal File.read('README.md'), File.read($basic + 'README.md')
    end

    it "should fail if the .gpg directory already exists" do
      FileUtils.mkdir_p $fixture + "create-4" + ".gpg"
      assert_fails(/\.gpg already exists/) do
        @dotgpg.invoke(:init, [($fixture + "create-4").to_s])
      end
    end

    it "can succeed if the directory itself already exists" do
      FileUtils.mkdir_p $fixture + "create-5"
      @dotgpg.invoke(:init, [($fixture + "create-5").to_s])
      assert $fixture.join("create-5", ".gpg").exist?
    end
  end

  describe "key" do
    it "should output the secret key" do
      assert_outputs GPGME::Key.find(:secret).first.export(armor: true).to_s do
        @dotgpg.invoke(:key)
      end
    end
  end

  describe "add" do
    before do
      @path = $fixture + rand.to_s.gsub(".", "")
      @path.mkdir
      Dir.chdir @path do
        Dotgpg::Cli.new.invoke(:init, [])
      end
    end

    it "should add the specified key" do
      key_path = ($fixture + "add1.key").to_s
      Dir.chdir @path do
        @dotgpg.invoke(:add, [key_path])
      end
      assert Dotgpg::Dir.new(@path).has_key? Dotgpg::Key.read(File.read(key_path))
    end

    it "should abort if the current working directory is not dotgpg" do
      key_path = ($fixture + "add1.key").to_s
      assert_fails(/not in a dotgpg directory/) do
        @dotgpg.invoke(:add, [key_path])
      end
    end

    it "should abort if the key cannot be read" do
      key_path = ($fixture + "no-add1.key").to_s
      Dir.chdir @path do
        assert_fails(/no-add1.key: not a valid GPG key/) do
          @dotgpg.invoke(:add, [key_path])
        end
      end
    end

    it "should abort if the key already exists" do
      key_path = ($fixture + "add1.key").to_s
      Dir.chdir @path do
        Dotgpg::Cli.new.invoke(:add, [key_path])

        assert_fails(/add1@example.com: already exists/) do
          @dotgpg.invoke(:add, [key_path])
        end
      end
    end

    it "should do nothing if the key exists and --force is specified" do
      key_path = ($fixture + "add1.key").to_s
      Dir.chdir @path do
        Dotgpg::Cli.new.invoke(:add, [key_path])

        @dotgpg.invoke(:add, [key_path], force: true)
      end
    end
  end

  describe "rm" do
    before do
      @path = $fixture + rand.to_s.gsub(".", "")
      @path.mkdir
      Dir.chdir @path do
        Dotgpg::Cli.new.invoke(:init, [])
        Dotgpg::Cli.new.invoke(:add, [($fixture + "add1.key").to_s])
      end
    end

    it "should remove the specified key" do
      Dir.chdir @path do
        @dotgpg.invoke :rm, [".gpg/add1@example.com"]
      end
      refute Dotgpg::Dir.new(@path).has_key? Dotgpg::Key.read(File.read($fixture + "add1.key"))
    end

    it "should find the key by email" do
      Dir.chdir @path do
        @dotgpg.invoke :rm, ["add1@example.com"]
      end
      refute Dotgpg::Dir.new(@path).has_key? Dotgpg::Key.read(File.read($fixture + "add1.key"))
    end

    it "should abort if the key doesn't exist" do
      Dir.chdir @path do
        assert_fails(/add2@example.com: not a valid GPG key/) do
          @dotgpg.invoke :rm, ["add2@example.com"]
        end
      end
    end

    it "should abort if the key is the user's secret key" do
      Dir.chdir @path do
        assert_fails(/test@example.com: refusing to remove your own secret key/) do
          @dotgpg.invoke :rm, ["test@example.com"]
        end
      end
    end

    it "should do nothing if they key doesn't exist and --force is specified" do
      Dir.chdir @path do
        @dotgpg.invoke :rm, ["add2@example.com"], force: true
      end
    end

    it "should remove a secret key if --force is given" do
      key = Dotgpg::Key.read(File.read(@path + ".gpg" + "test@example.com"))
      Dir.chdir @path do
        @dotgpg.invoke :rm, ["test@example.com"], force: true
      end

      refute Dotgpg::Dir.new(@path).has_key? key
    end
  end

  describe "cat" do
    before do
      Dotgpg.passphrase = 'test'

      @path = $fixture + rand.to_s.gsub(".", "")
      Dotgpg::Cli.new.invoke(:init, [@path.to_s])
      Dotgpg::Dir.new(@path).encrypt @path + "a", "Test\n"
    end

    it "should cat an existing encrypted file" do
      assert_outputs "Test\n" do
        @dotgpg.invoke :cat, [(@path + "a").to_s]
      end
    end

    it "should warn if a file doesn't exist" do
      assert_warns "#{@path + "b"}: No such file or directory" do
        @dotgpg.invoke :cat, [(@path + "b").to_s]
      end
    end

    it "should cat the existing files if a mixture is specified" do
      assert_outputs "Test\n" do
        assert_warns  "#{@path + "b"}: No such file or directory" do
          @dotgpg.invoke :cat, [(@path + "b").to_s, (@path + "a").to_s]
        end
      end
    end

    it "should fail if the file is not in a .gpg directory" do
      assert_fails "not in a dotgpg directory" do
        @dotgpg.invoke :cat, ["/tmp/b"]
      end
    end

    it "should fail if the passphrase is wrong" do
      Dotgpg.passphrase = 'wrong'
      assert_fails "Bad passphrase" do
        @dotgpg.invoke :cat, [(@path + "a").to_s]
      end
    end
  end

  describe "create" do
    before do
      Dotgpg.passphrase = 'test'
      @path = $fixture + rand.to_s.gsub(".", "")
      Dotgpg::Cli.new.invoke(:init, [@path.to_s])
      Dotgpg::Dir.new(@path).encrypt @path + "a", "Bad test\n"
    end

    it "creates a new encrypted file from command line input" do
      path = (@path + "a").to_s
      @dotgpg.send(:create, path, 'Some test data here')
      expect {Dotgpg::Dir.new(@path).decrypt(path, $stdout)}.to output('Some test data here').to_stdout
    end
  end

  describe "edit" do
    before do
      Dotgpg.passphrase = 'test'

      @path = $fixture + rand.to_s.gsub(".", "")
      Dotgpg::Cli.new.invoke(:init, [@path.to_s])
      Dotgpg::Dir.new(@path).encrypt @path + "a", "Bad test\n"

    end

    it "should let you edit an existing file" do
      ENV['EDITOR'] = "sed -i '' s/Bad/Good/"
      path = (@path + "a").to_s
      @dotgpg.invoke(:edit, [path])
      assert_outputs "Good test\n" do
        Dotgpg::Dir.new(@path).decrypt path, $stdout
      end
    end

    it "should open a non-existing file as blank" do
      ENV['EDITOR'] = "ruby -e 'File.write(ARGV[0], %(Good test\n)) if File.read(ARGV[0]) == %()'"
      path = (@path + "b").to_s
      @dotgpg.invoke(:edit, [path])
      assert_outputs "Good test\n" do
        Dotgpg::Dir.new(@path).decrypt path, $stdout
      end
    end

    it "should warn if a file cannot be decrypted" do
      File.write(@path + "d", "not encrypted...")
      path = (@path + "d").to_s
      assert_warns "#{@path + "d"}: No data" do
        @dotgpg.invoke(:edit, [path])
      end
    end

    it "should fail if invoking the editor doesn't work" do
      ENV['EDITOR'] = 'not-an-editor'
      assert_fails "Problem with editor. Not saving changes" do
        @dotgpg.invoke :edit, [(@path + "a").to_s]
      end
    end

    it "should edit the existing files if a mixture is specified" do

    end
  end
end
