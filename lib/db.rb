require 'sequel'
require 'yaml'

environment = ENV['RACK_ENV'] || 'default'
CONFIG = YAML::load_file("config.yml")[environment]
DB = Sequel.connect CONFIG['database']

