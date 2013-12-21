task :test do
  Dir['./spec/**/*_spec.rb'].each do |f|
    require f
  end
end

task :default => :test
