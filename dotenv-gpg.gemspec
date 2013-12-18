Gem::Specification.new do |gem|
  gem.name = 'dotenv-gpg'
  gem.version = '0.1'

  gem.summary = 'gpg-encrypted backup for your dotenv files'
  gem.description = "Easy management of gpg-encrypted backup files"

  gem.authors = ['Conrad Irwin']
  gem.email = %w(conrad@bugsnag.com)
  gem.homepage = 'http://github.com/ConradIrwin/dotenv-gpg'

  gem.license = 'MIT'

  gem.add_dependency 'thor'
  gem.add_dependency 'gpgme'

  gem.add_development_dependency 'pry'
  gem.add_development_dependency 'pry-stack_explorer'

  gem.executables = 'gpgenv'
  gem.files = `git ls-files`.split("\n")
end
