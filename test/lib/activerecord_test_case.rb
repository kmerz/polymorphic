require 'rubygems'
require 'active_record'

ActiveRecord::Base.establish_connection({
  :adapter => 'sqlite3',
	:database => 'test.db',
	:dbfile => 'test.db'
})
