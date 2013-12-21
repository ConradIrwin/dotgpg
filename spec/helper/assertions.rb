module Minitest::Assertions

  def hex_gpg_bytes(data)
    require 'base64'
    raw = Base64.decode64(data.split("\n\n").last.split("\n=").first)
    raw.bytes.map{ |x| x.to_s(16).rjust(2, "0") }.join.upcase
  end

  def assert_contains_keyid(keyid, data)
    # 03 is the version tag of the Public Key Encrypted Session Key packet emitted
    # by the current version of GPGME.
    # 01 identifies the key as an RSA key.
    assert_match Regexp.new("03#{keyid}01"), hex_gpg_bytes(data)
  end

  def refute_contains_keyid(keyid, data)
    refute_match Regexp.new("03#{keyid}01"), hex_gpg_bytes(data)
  end

  def assert_warns(expected, &block)
    actual = nil
    Dotgpg.singleton_class.class_eval do

      alias_method :warn_without_asserts, :warn
      define_method :warn do |context, e|
        actual = "#{context}: #{e.message.gsub(/\W*#{context}/, '')}"
      end
    end
    yield
    assert_equal expected, actual
  ensure
    Dotgpg.singleton_class.class_eval do
      alias_method :warn, :warn_without_asserts
    end
  end

  def assert_outputs(expected, &block)
    old_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.rewind
    assert_equal expected, $stdout.read
  ensure
    $stdout = old_stdout
  end

  def assert_fails(expected, &block)
    yield
  rescue Dotgpg::Failure => e
    assert_match expected, e.message
  else
    assert false, "did not fail"
  end
end
