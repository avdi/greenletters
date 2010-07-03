
begin
  require 'bones'
rescue LoadError
  abort '### Please install the "bones" gem ###'
end

task :default => 'test:run'
task 'gem:release' => 'test:run'

Bones {
  name  'greenletters'
  authors  'Avdi Grimm'
  email  'avdi@avdi.org'
  url  'http://github.com/avdi/greenletters'
  ignore_file  '.gitignore'
}

