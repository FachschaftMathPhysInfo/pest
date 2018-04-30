# encoding: utf-8

# extends the PESTOmr with some database related tools. Connecting to
# the database is handled by lib/result_tools.rb.

cdir = File.dirname(__FILE__)
require cdir + '/helper.misc.rb'
require cdir + '/../lib/result_tools.rb'

class PESTDatabaseTools
  RT = ResultTools.instance

  def set_debug_database
    debug "WARNING: Debug mode is enabled, writing to db.sqlite3 in working directory instead of real database." if @verbose && !@test_mode
    Seee::Config.external_database[:dbi_handler] = "SQLite3"
    Seee::Config.external_database[:database] = "#{@path}/db.sqlite3"
    RT.reconnect_to_database
  end

  def list_available_tables
    tables = []
    x = case Seee::Config.external_database[:dbi_handler].downcase
      when "sqlite3" then "SELECT name FROM sqlite_master WHERE type='table'"
      when "mysql"   then "SHOW TABLES"
      # via http://bytes.com/topic/postgresql/answers/172978-sql-command-list-tables#post672429
      when "pg"      then "select c.relname FROM pg_catalog.pg_class c
  LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
  WHERE c.relkind IN ('r','') AND n.nspname NOT IN ('pg_catalog', 'pg_toast')
  AND pg_catalog.pg_table_is_visible(c.oid);"
      else            raise("Unsupported database handler")
    end
    RT.custom_query(x).each { |y| tables << y.values[0] }
    tables
  end
end
