# frozen_string_literal: true

require_relative "lib/inlay/version"

Gem::Specification.new do |spec|
  spec.name = "inlay"
  spec.version = Inlay::VERSION
  spec.authors = ["Yudai Takada"]
  spec.email = ["t.yudai92@gmail.com"]

  spec.summary = "Display Ruby graphics in terminals and REPLs"
  spec.description = "Render Tessel images, graphics buffers, charts, and animations in terminals, IRB, Pry, and IRuby."
  spec.homepage = "https://github.com/rbgfx/inlay"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/rbgfx/inlay/tree/main"

  # Uncomment the line below to require MFA for gem pushes.
  # This helps protect your gem from supply chain attacks by ensuring
  # no one can publish a new version without multi-factor authentication.
  # See: https://guides.rubygems.org/mfa-requirement-opt-in/
  # spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.add_dependency "tessel", ">= 0.2.0", "< 1"
  spec.add_dependency "termvas", ">= 0.3.0", "< 1"
  spec.add_dependency "base64", ">= 0.2", "< 1"
  spec.add_development_dependency "irb", ">= 1.13", "< 2"
  spec.add_development_dependency "iruby", ">= 0.8", "< 1"
  spec.add_development_dependency "pry", ">= 0", "< 1"
  spec.add_development_dependency "rspec", "~> 3.0"

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://guides.rubygems.org/make-your-own-gem/
end
