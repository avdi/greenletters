# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{greenletters}
  s.version = "0.1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Avdi Grimm"]
  s.date = %q{2010-07-31}
  s.default_executable = %q{greenletters}
  s.description = %q{    Greenletterrs is a console automation framework, similar to the classic
    utility Expect. You give it a command to execute, and tell it which outputs
    or events to expect and how to respond to them.

    Greenletters also includes a set of Cucumber steps which simplify the task
    of spcifying interactive command-line applications.
}
  s.email = %q{avdi@avdi.org}
  s.executables = ["greenletters"]
  s.extra_rdoc_files = ["History.txt", "bin/greenletters", "version.txt"]
  s.files = ["History.txt", "README.org", "Rakefile", "bin/greenletters", "examples/adventure.rb", "examples/cucumber/adventure.feature", "examples/cucumber/greenletters.log", "examples/cucumber/support/env.rb", "lib/greenletters.rb", "lib/greenletters/cucumber_steps.rb", "script/console", "spec/greenletters_spec.rb", "spec/spec_helper.rb", "test/test_greenletters.rb", "version.txt"]
  s.homepage = %q{http://github.com/avdi/greenletters}
  s.rdoc_options = ["--main", "README.org"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{greenletters}
  s.rubygems_version = %q{1.3.6}
  s.summary = %q{A Ruby console automation framework a la Expect}
  s.test_files = ["test/test_greenletters.rb"]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<bones>, [">= 3.4.7"])
    else
      s.add_dependency(%q<bones>, [">= 3.4.7"])
    end
  else
    s.add_dependency(%q<bones>, [">= 3.4.7"])
  end
end
