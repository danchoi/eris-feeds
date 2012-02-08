dropdb erisfeeds
createdb erisfeeds
psql erisfeeds < db/schema.psql
ruby -Ilib db/seed.rb

