# This file begins the loading sequence.
#
# Quick Overview:
# * Requires fastthread, support libs, and base.
# * Sets the application root and environment for compatibility with frameworks
#   such as Rails or Merb.
# * Checks for the database.yml and loads it if it exists.
# * Sets up the database using the config from the Yaml file or from the
#   environment.
#

require 'date'
require 'pathname'
require 'set'
require 'time'
require 'yaml'

require 'rubygems'

gem 'addressable', '~>2.0'
require 'addressable/uri'

gem 'extlib', '~>0.9.10'
require 'extlib'
require 'extlib/inflection'

begin
  require 'fastthread'
rescue LoadError
  # fastthread not installed
end

dir = Pathname(__FILE__).dirname.expand_path / 'dm-core'

require dir / 'core_ext'
require dir / 'support'
require dir / 'version'

require dir / 'resource'
require dir / 'model'
require dir / 'collection'

require dir / 'type'
require dir / 'types'
require dir / 'associations'
require dir / 'identity_map'
require dir / 'property_set'
require dir / 'query'
require dir / 'repository'
require dir / 'property'
require dir / 'adapters'

require dir / 'transaction'
require dir / 'migrations'

# == Setup and Configuration
# DataMapper uses URIs or a connection hash to connect to your data-store.
# URI connections takes the form of:
#   DataMapper.setup(:default, 'protocol://username:password@localhost:port/path/to/repo')
#
# Breaking this down, the first argument is the name you wish to give this
# connection.  If you do not specify one, it will be assigned :default. If you
# would like to connect to more than one data-store, simply issue this command
# again, but with a different name specified.
#
# In order to issue ORM commands without specifying the repository context, you
# must define the :default database. Otherwise, you'll need to wrap your ORM
# calls in <tt>repository(:name) { }</tt>.
#
# Second, the URI breaks down into the access protocol, the username, the
# server, the password, and whatever path information is needed to properly
# address the data-store on the server.
#
# Here's some examples
#   DataMapper.setup(:default, "sqlite3://path/to/your/project/db/development.db")
#   DataMapper.setup(:default, "mysql://localhost/dm_core_test")
#     # no auth-info
#   DataMapper.setup(:default, "postgres://root:supahsekret@127.0.0.1/dm_core_test")
#     # with auth-info
#
#
# Alternatively, you can supply a hash as the second parameter, which would
# take the form:
#
#   DataMapper.setup(:default, {
#     :adapter  => 'adapter_name_here',
#     :database => "path/to/repo",
#     :username => 'username',
#     :password => 'password',
#     :host     => 'hostname'
#   })
#
# === Logging
# To turn on error logging to STDOUT, issue:
#
#   DataMapper::Logger.new(STDOUT, 0)
#
# You can pass a file location ("/path/to/log/file.log") in place of STDOUT.
# see DataMapper::Logger for more information.
#
module DataMapper
  extend Extlib::Assertions

  # TODO: move to dm-validations
  class ValidationError < StandardError; end

  class ObjectNotFoundError < StandardError; end

  class RepositoryNotSetupError < StandardError; end

  class IncompleteModelError < StandardError; end

  class PluginNotFoundError < StandardError; end

  def self.root
    @root ||= Pathname(__FILE__).dirname.parent.expand_path.freeze
  end

  ##
  # Setups up a connection to a data-store
  #
  # @param Symbol name a name for the context, defaults to :default
  # @param [Hash(Symbol => String), Addressable::URI, String] uri_or_options
  #   connection information
  #
  # @return Repository the resulting setup repository
  #
  # @raise ArgumentError "+name+ must be a Symbol, but was..." indicates that
  #   an invalid argument was passed for name[Symbol]
  # @raise [ArgumentError] "+uri_or_options+ must be a Hash, URI or String,
  #   but was..." indicates that connection information could not be gleaned
  #   from the given uri_or_options<Hash, Addressable::URI, String>
  #
  # @api public
  def self.setup(name, uri_or_options)
    assert_kind_of 'name', name, Symbol

    options = Adapters::AbstractAdapter.normalize_options(uri_or_options)

    adapter_name = options[:adapter]
    class_name   = (Extlib::Inflection.classify(adapter_name) + 'Adapter').to_sym

    unless Adapters.const_defined?(class_name)
      lib_name = "#{adapter_name}_adapter"

      begin
        require root / 'lib' / 'dm-core' / 'adapters' / lib_name
      rescue LoadError
        require lib_name
      end
    end

    Repository.adapters[name] = Adapters.const_get(class_name).new(name, options)
  end

  ##
  # Block Syntax
  #   Pushes the named repository onto the context-stack,
  #   yields a new session, and pops the context-stack.
  #
  # Non-Block Syntax
  #   Returns the current session, or if there is none,
  #   a new Session.
  #
  # @param [Symbol] args the name of a repository to act within or return, :default is default
  # @yield [Proc] (optional) block to execute within the context of the named repository
  # @demo spec/integration/repository_spec.rb
  def self.repository(name = nil) # :yields: current_context
    current_repository = if name
      raise ArgumentError, "First optional argument must be a Symbol, but was #{name.inspect}" unless name.kind_of?(Symbol)
      Repository.context.detect { |r| r.name == name } || Repository.new(name)
    else
      Repository.context.last || Repository.new(Repository.default_name)
    end

    if block_given?
      current_repository.scope { |*block_args| yield(*block_args) }
    else
      current_repository
    end
  end

  # A logger should always be present. Lets be consistent with DO
  Logger.new(nil, :off)
end
