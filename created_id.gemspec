Gem::Specification.new do |spec|
  spec.name = "created_id"
  spec.version = File.read(File.expand_path("../VERSION", __FILE__)).strip
  spec.authors = ["Brian Durand"]
  spec.email = ["bbdurand@gmail.com"]

  spec.summary = "Optimize ActiveRecord queries for filtering large tables on the created_at column by pre-computing id ranges."
  spec.homepage = "https://github.com/bdurand/created_id"
  spec.license = "MIT"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md"
  }

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  ignore_files = %w[
    .
    Appraisals
    Gemfile
    Gemfile.lock
    Rakefile
    bin/
    gemfiles/
    spec/
  ]
  spec.files = Dir.chdir(File.expand_path("..", __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| ignore_files.any? { |path| f.start_with?(path) } }
  end

  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", ">= 6.0"

  spec.add_development_dependency "bundler"

  spec.required_ruby_version = ">= 2.7"
end
