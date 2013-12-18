require "./spec/helper"

describe Dotgpg::Dir do
  describe "dotgpg?" do
    it 'should be true in a directory managed by dotgpg' do
      assert_equal true, Dotgpg::Dir.new("spec/fixture/basic").dotgpg?
    end

    it 'should not be true in a random directory' do
      assert_equal false, Dotgpg::Dir.new("spec").dotgpg?
    end

    it "should not be true in a directory that doesn't exist" do
      assert_equal false, Dotgpg::Dir.new(rand.to_s).dotgpg?
    end
  end

  describe "all_encrypted_files" do
    before do
      @files = Dotgpg::Dir.new("spec/fixture/basic").all_encrypted_files
    end

    it "should find files in the top-level" do
      assert_includes @files, Pathname.new("spec/fixture/basic/a")
    end

    it "should find files in sub-directories" do
      assert_includes @files, Pathname.new("spec/fixture/basic/b/c")
    end

    it "should not find unencrypted files" do
      readme = Pathname.new("spec/fixture/basic/README.md")
      assert readme.exist?
      refute_includes @files, readme
    end

    it "should not find files through symlinks" do
      duplicate_a = Pathname.new("spec/fixture/basic/c/basic/a")
      assert duplicate_a.exist?
      refute_includes @files, duplicate_a
    end
  end
end
