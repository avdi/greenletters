begin
  require 'bones'
rescue LoadError
  abort '### Please install the "bones" gem ###'
end

task :default do
  sh "bundle exec rspec spec"
end

task 'gem:release' => :default

Bones {
  name         'greenletters'
  authors      'Avdi Grimm'
  email        'avdi@avdi.org'
  url          'http://github.com/avdi/greenletters'
  ignore_file  '.gitignore'
  ignore_file '.idea'
  readme_file  'README.org'

  summary      'A Ruby console automation framework a la Expect'

  description  <<-END
    Greenletterrs is a console automation framework, similar to the classic
    utility Expect. You give it a command to execute, and tell it which outputs
    or events to expect and how to respond to them.

    Greenletters also includes a set of Cucumber steps which simplify the task
    of spcifying interactive command-line applications.
  END
}

