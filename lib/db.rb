require 'sequel'
require 'yaml'
environment = ENV['RACK_ENV'] || 'development'
c = YAML::load_file("config.yml")
puts "racking up in #{environment} environment"
CONFIG = c[environment]
DB = Sequel.connect CONFIG['database']

