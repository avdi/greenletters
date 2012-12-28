# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "greenletters"
  s.version = "0.3.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Avdi Grimm"]
  s.date = "2012-12-28"
  s.description = "    Greenletterrs is a console automation framework, similar to the classic\n    utility Expect. You give it a command to execute, and tell it which outputs\n    or events to expect and how to respond to them.\n\n    Greenletters also includes a set of Cucumber steps which simplify the task\n    of spcifying interactive command-line applications.\n"
  s.email = "avdi@avdi.org"
  s.executables = ["greenletters"]
  s.extra_rdoc_files = ["History.txt", "bin/greenletters"]
  s.files = [".gitignore", "Gemfile", "Gemfile.lock", "History.txt", "README.org", "Rakefile", "bin/greenletters", "examples/adventure.rb", "examples/cucumber/adventure.feature", "examples/cucumber/support/env.rb", "greenletters.gemspec", "lib/greenletters.rb", "lib/greenletters/cucumber_steps.rb", "script/console", "spec/greenletters_spec.rb", "spec/spec_helper.rb", "version.txt"]
  s.homepage = "http://github.com/avdi/greenletters"
  s.rdoc_options = ["--main", "README.org"]
  s.require_paths = ["lib"]
  s.rubyforge_project = "greenletters"
  s.rubygems_version = "1.8.10"
  s.summary = "A Ruby console automation framework a la Expect"

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<bones>, [">= 3.8.0"])
    else
      s.add_dependency(%q<bones>, [">= 3.8.0"])
    end
  else
    s.add_dependency(%q<bones>, [">= 3.8.0"])
  end
end
