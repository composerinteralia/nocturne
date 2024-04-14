# frozen_string_literal: true

require_relative "lib/nocturne/version"

Gem::Specification.new do |spec|
  spec.name = "nocturne"
  spec.version = Nocturne::VERSION
  spec.authors = ["Daniel Colson"]
  spec.email = ["danieljamescolson@gmail.com"]

  spec.summary = "Placeholder"
  spec.description = "Placeholder"
  spec.homepage = "https://github.com/composerinteralia/nocturne"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/composerinteralia/nocturne"
  spec.metadata["changelog_uri"] = "https://github.com/composerinteralia/nocturne"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ .git .github Gemfile])
    end
  end
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency("bigdecimal")
end
