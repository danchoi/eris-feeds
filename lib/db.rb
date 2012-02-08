require 'sequel'
require 'yaml'
environment = ENV['RACK_ENV'] || 'development'
c = YAML::load_file("config.yml")
CONFIG = c[environment]
DB = Sequel.connect CONFIG['database']

