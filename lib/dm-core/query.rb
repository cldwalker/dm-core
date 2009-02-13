module DataMapper

  # Query class represents a query which will be run against the data-store.
  # Generally Query objects can be found inside Collection objects.
  #
  class Query
    include Extlib::Assertions

    OPTIONS = [ :fields, :links, :conditions, :offset, :limit, :order, :unique, :add_reversed, :reload ].to_set.freeze

    ##
    # Returns the repository
    #
    #   TODO: needs example
    #
    # @return [Repository]
    #   the Repository to retrieve results from
    #
    # @api semipublic
    attr_reader :repository

    ##
    # Returns the model
    #
    #   TODO: needs example
    #
    # @return [Model]
    #   the Model to retrieve results from
    #
    # @api semipublic
    attr_reader :model

    ##
    # Returns the fields
    #
    #   TODO: needs example
    #
    # @return [PropertySet]
    #   the properties in the Model that will be retrieved
    #
    # @api semipublic
    attr_reader :fields

    ##
    # Returns the links
    #
    #   TODO: needs example
    #
    # @return [Array]
    #   the relationships that will be used to scope the results
    #
    # @api semipublic
    attr_reader :links

    ##
    # Returns the conditions
    #
    #   TODO: needs example
    #
    # @return [Array]
    #   the conditions that will be used to scope the results
    #
    # @api semipublic
    attr_reader :conditions

    ##
    # Returns the offset
    #
    #   TODO: needs example
    #
    # @return [Integer]
    #   the offset of the results
    #
    # @api semipublic
    attr_reader :offset

    ##
    # Returns the limit
    #
    #   TODO: needs example
    #
    # @return [Integer,NilClass]
    #   the maximum number of results
    #
    # @api semipublic
    attr_reader :limit

    ##
    # Returns the order
    #
    #   TODO: needs example
    #
    # @return [Array]
    #   the order of results
    #
    # @api semipublic
    attr_reader :order

    ##
    # Returns the original options
    #
    #   TODO: needs example
    #
    # @return [Hash]
    #   the original options
    #
    # @api private
    attr_reader :options

    # TODO: move these checks inside assert_valid_conditions and blow
    # up if invalid conditions used
    #def valid?
    #  !conditions.any? do |operator, property, bind_value|
    #    next if :raw == operator
    #
    #    case bind_value
    #      when Array
    #        bind_value.empty?
    #      when Range
    #        operator != :eql && operator != :in && operator != :not
    #    end
    #  end
    #end

    ##
    # Indicates if each result should be returned in reverse order
    #
    #   TODO: needs example
    #
    # @return [TrueClass,FalseClass]
    #   true if the results should be reversed, false if not
    #
    # @api private
    def add_reversed?
      @add_reversed
    end

    ##
    # Indicates if the Query results should replace the results in the Identity Map
    #
    #   TODO: needs example
    #
    # @return [TrueClass, FalseClass]
    #   true if the results should be reloaded, false if not
    #
    # @api semipublic
    def reload?
      @reload
    end

    ##
    # Indicates if the Query results should be unique
    #
    #   TODO: needs example
    #
    # @return [TrueClass, FalseClass]
    #   true if the results should be unique, false if not
    #
    # @api semipublic
    def unique?
      @unique
    end

    ##
    # Returns a new Query with a reversed order
    #
    #   TODO: needs example
    #
    # @return [Query]
    #   new Query with reversed order
    #
    # @api semipublic
    def reverse
      dup.reverse!
    end

    ##
    # Reverses the sort order of the Query
    #
    #   TODO: needs example
    #
    # @return [Query]
    #   self
    #
    # @api semipublic
    def reverse!
      # reverse the sort order
      @order.map! { |o| o.reverse! }

      self
    end

    ##
    # Updates the Query with another Query or conditions
    #
    #   TODO: needs example
    #
    # @param [Query, Hash] other
    #   other Query or conditions
    #
    # @return [Query]
    #   self
    #
    # @api semipublic
    def update(other)
      assert_kind_of 'other', other, self.class, Hash

      options = case other
        when self.class
          if self.eql?(other)
            return self
          end

          assert_valid_other(other)

          @options.merge(other.options)
        when Hash
          if other.empty?
            return self
          end

          @options.merge(other)
      end

      reset_memoized_vars

      initialize(repository, model, options)

      self
    end

    ##
    # Similar to Query#update, but acts on a duplicate.
    #
    # @param [Query, Hash] other
    #   other query to merge with
    #
    # @return [Query]
    #   updated duplicate of original query
    #
    # @api semipublic
    def merge(other)
      dup.update(other)
    end

    # TODO: document this
    #   TODO: needs example
    # @api semipublic
    def relative(options)
      assert_kind_of 'options', options, Hash

      options = options.dup

      repository = options.delete(:repository) || self.repository

      if repository.kind_of?(Symbol)
        repository = DataMapper.repository(repository)
      end

      if options.key?(:offset) && (options.key?(:limit) || self.limit)
        offset = options.delete(:offset)
        limit  = options.delete(:limit) || self.limit - offset

        self.class.new(repository, model, @options.merge(options)).slice!(offset, limit)
      else
        self.class.new(repository, model, @options.merge(options))
      end
    end

    ##
    # Compares another Query for equivalency
    #
    #   TODO: needs example
    #
    # @param [Query] other
    #   the other Query to compare with
    #
    # @return [TrueClass, FalseClass]
    #   true if they are equivalent, false if not
    #
    # @api semipublic
    def ==(other)
      if equal?(other)
        return true
      end

      unless other.respond_to?(:repository) && other.respond_to?(:model) && other.respond_to?(:to_hash)
        return false
      end

      cmp?(other, :==)
    end

    ##
    # Compares another Query for equality
    #
    #   TODO: needs example
    #
    # @param [Query] other
    #   the other Query to compare with
    #
    # @return [TrueClass, FalseClass]
    #   true if they are equal, false if not
    #
    # @api semipublic
    def eql?(other)
      if equal?(other)
        return true
      end

      unless other.class.equal?(self.class)
        return false
      end

      cmp?(other, :eql?)
    end

    # TODO: document this
    #   TODO: needs example
    # @api semipublic
    def slice(*args)
      dup.slice!(*args)
    end

    # TODO: document this
    #   TODO: needs example
    # @api semipublic
    def slice!(*args)
      offset, limit = extract_slice_arguments(*args)

      if self.limit || self.offset > 0
        offset, limit = get_relative_position(offset, limit)
      end

      update(:offset => offset, :limit => limit)
    end

    # TODO: document this
    #   TODO: needs example
    # @api semipublic
    def to_hash
      hash = {
        :fields       => fields,
        :order        => order,
        :offset       => offset,
        :reload       => reload?,
        :unique       => unique?,
        :add_reversed => add_reversed?,
      }

      hash[:limit] = limit unless limit == nil
      hash[:links] = links unless links == []

      conditions  = {}
      raw_queries = []
      bind_values = []

      self.conditions.each do |tuple|
        if tuple[0] == :raw
          raw_queries << tuple[1]
          bind_values << tuple[2] if tuple.size == 3
        else
          operator, property, bind_value = tuple
          conditions[Query::Operator.new(property, operator)] = bind_value
        end
      end

      if raw_queries.any?
        hash[:conditions] = [ raw_queries.map { |q| "(#{q})" }.join(' AND ') ].concat(bind_values)
      end

      hash.update(conditions)
    end

    # TODO: document this
    #   TODO: needs example
    # @api semipublic
    def inspect
      attrs = [
        [ :repository, repository.name ],
        [ :model,      model           ],
        [ :fields,     fields          ],
        [ :links,      links           ],
        [ :conditions, conditions      ],
        [ :order,      order           ],
        [ :limit,      limit           ],
        [ :offset,     offset          ],
        [ :reload,     reload?         ],
        [ :unique,     unique?         ],
      ]

      "#<#{self.class.name} #{attrs.map { |k, v| "@#{k}=#{v.inspect}" } * ' '}>"
    end

    # TODO: document this
    #   TODO: needs example
    # @api private
    def bind_values
      @bind_values ||=
        begin
          bind_values = []

          conditions.each do |tuple|
            next if tuple.size == 2
            operator, property, bind_value = *tuple

            if :raw == operator
              bind_values.push(*bind_value)
            else
              if bind_value.kind_of?(Range) && bind_value.exclude_end? && (operator == :eql || operator == :not)
                bind_values.push(bind_value.first, bind_value.last)
              else
                bind_values << bind_value
              end
            end
          end

          bind_values
        end
    end

    # TODO: document this
    #   TODO: needs example
    # @api private
    def inheritance_property_index
      if defined?(@inheritance_property_index)
        return @inheritance_property_index
      end

      fields.each_with_index do |property, i|
        if property.type == Types::Discriminator
          break @inheritance_property_index = i
        end
      end

      @inheritance_property_index
    end

    ##
    # Get the indices of all keys in fields
    #
    #   TODO: needs example
    #
    # @api private
    def key_property_indexes
      @key_property_indexes ||=
        begin
          indexes = []

          fields.each_with_index do |property, i|
            if property.key?
              indexes << i
            end
          end

          indexes
        end
    end

    private

    ##
    # Initializes a Query instance
    #
    #   TODO: needs example
    #
    # @param [Repository] repository
    #   the Repository to retrieve results from
    # @param [Model] model
    #   the Model to retrieve results from
    # @param [Hash] options
    #   the conditions and scope
    #
    # @api semipublic
    def initialize(repository, model, options = {})
      assert_kind_of 'repository', repository, Repository
      assert_kind_of 'model',      model,      Model

      @repository = repository
      @model      = model
      @options    = options.dup.freeze

      repository_name = repository.name

      @properties    = @model.properties(repository_name)
      @relationships = @model.relationships(repository_name)

      assert_valid_options(@options)

      @fields       = @options.fetch :fields,       @properties.defaults  # must be an Array of Symbol, String or DM::Property
      @links        = @options.fetch :links,        []     # must be an Array of Tuples - Tuple [DM::Query,DM::Assoc::Relationship]
      @conditions   = []                                  # must be an Array of triplets (or pairs when passing in raw String queries)
      @offset       = @options.fetch :offset,       0      # must be an Integer greater than or equal to 0
      @limit        = @options.fetch :limit,        nil    # must be an Integer greater than or equal to 1
      @order        = @options.fetch :order,        @model.default_order(repository_name)   # must be an Array of Symbol, DM::Query::Direction or DM::Property
      @unique       = @options.fetch :unique,       false  # must be true or false
      @add_reversed = @options.fetch :add_reversed, false  # must be true or false
      @reload       = @options.fetch :reload,       false  # must be true or false

      # XXX: should I validate that each property in @order corresponds
      # to something in @fields?  Many DB engines require they match,
      # and I can think of no valid queries where a field would be so
      # important that you sort on it, but not important enough to
      # return.

      @links = @links.dup

      normalize_order
      normalize_fields
      normalize_links

      # treat all non-options as conditions
      @options.except(*OPTIONS).each { |kv| append_condition(*kv) }

      # parse raw @options[:conditions] differently
      if conditions = @options[:conditions]
        case conditions
          when Hash
            conditions.each { |kv| append_condition(*kv) }
          when Array
            @conditions << [ :raw, *conditions ]
        end
      end

      # normalize any newly added links
      normalize_links
    end

    # TODO: document this
    #   TODO: needs example
    # @api semipublic
    def initialize_copy(original)
      # TODO: test to see if this is necessary.  The idea is to ensure
      # that changes to the duped object (such as via Query#reverse!)
      # do not alter the original object
      @order      = original.order.map      { |o| o.dup }
      @conditions = original.conditions.map { |c| c.dup }
    end

    ##
    # Validate the options
    #
    #   TODO: needs example
    #
    # @param [#each] options
    #   the options to validate
    #
    # @raise [ArgumentError]
    #   if any pairs in +options+ are invalid options
    #
    # @api private
    def assert_valid_options(options)
      assert_kind_of 'options', options, Hash

      options.each do |attribute, value|
        next unless OPTIONS.include?(attribute)

        case attribute
          when :fields                         then assert_valid_fields(value, options[:unique])
          when :links                          then assert_valid_links(value)
          when :conditions                     then assert_valid_conditions(value)
          when :offset                         then assert_valid_offset(value, options[:limit])
          when :limit                          then assert_valid_limit(value)
          when :order                          then assert_valid_order(value, options[:fields])
          when :unique, :add_reversed, :reload then assert_valid_boolean("options[:#{attribute}]", value)
        end
      end
    end

    # TODO: document this
    # @api private
    def assert_valid_fields(fields, unique)
      assert_kind_of 'options[:fields]', fields, Array

      if fields.empty? && unique == false
        raise ArgumentError, '+options[:fields]+ should not be empty if +options[:unique]+ is false', caller(3)
      end

      fields.each do |field|
        case field
          when Property
            unless @properties.include?(field)
              raise ArgumentError, "+options[:field]+ entry #{field.name.inspect} does not map to a property", caller(3)
            end

          # TODO: mix-in Operator validation for fields in dm-aggregates
          #when Operator
          #  target = field.target
          #
          #  unless target.kind_of?(Property) && @properties.include?(target)
          #    raise ArgumentError, "+options[:fields]+ entry #{target.inspect} does not map to a property", caller(3)
          #  end

          when Symbol, String
            unless @properties.named?(field)
              raise ArgumentError, "+options[:fields]+ entry #{field.inspect} does not map to a property", caller(3)
            end

          else
            raise ArgumentError, "+options[:fields]+ entry #{field.inspect} of an unsupported object #{field.class}", caller(3)
        end
      end
    end

    # TODO: document this
    # @api private
    def assert_valid_links(links)
      assert_kind_of 'options[:links]', links, Array

      if links.empty?
        raise ArgumentError, '+options[:links]+ should not be empty', caller(3)
      end

      links.each do |link|
        case link
          when Associations::Relationship
            # TODO: figure out how to validate links from other models
            #unless @relationships.value?(link)
            #  raise ArgumentError, "+options[:links]+ entry #{link.name.inspect} does not map to a relationship", caller(3)
            #end

          when Symbol, String
            unless @relationships.key?(link.to_sym)
              raise ArgumentError, "+options[:links]+ entry #{link.inspect} does not map to a relationship", caller(3)
            end

          else
            raise ArgumentError, "+options[:links]+ entry #{link.inspect} of an unsupported object #{link.class}", caller(3)
        end
      end
    end

    # TODO: document this
    # @api private
    def assert_valid_conditions(conditions)
      assert_kind_of 'options[:conditions]', conditions, Hash, Array

      if conditions.empty?
        raise ArgumentError, '+options[:conditions]+ should not be empty', caller(3)
      end
    end

    # TODO: document this
    # @api private
    def assert_valid_offset(offset, limit)
      assert_kind_of 'options[:offset]', offset, Integer

      unless offset >= 0
        raise ArgumentError, "+options[:offset]+ must be greater than or equal to 0, but was #{offset.inspect}", caller(3)
      end

      if offset > 0 && limit.nil?
        raise ArgumentError, '+options[:offset]+ cannot be greater than 0 if limit is not specified', caller(3)
      end
    end

    # TODO: document this
    # @api private
    def assert_valid_limit(limit)
      assert_kind_of 'options[:limit]', limit, Integer

      unless limit >= 1
        raise ArgumentError, "+options[:limit]+ must be greater than or equal to 1, but was #{limit.inspect}", caller(3)
      end
    end

    # TODO: document this
    # @api private
    def assert_valid_order(order, fields)
      assert_kind_of 'options[:order]', order, Array

      if order.empty? && fields && fields.any? { |p| !p.kind_of?(Operator) }
        raise ArgumentError, '+options[:order]+ should not be empty if +options[:fields] contains a non-operator', caller(3)
      end

      order.each do |order|
        case order
          when Direction
            unless @properties.include?(order.property)
              raise ArgumentError, "+options[:order]+ entry #{order.property.name.inspect} does not map to a property", caller(3)
            end

          when Property
            unless @properties.include?(order)
              raise ArgumentError, "+options[:order]+ entry #{order.name.inspect} does not map to a property", caller(3)
            end

          when Operator
            unless order.operator == :asc || order.operator == :desc
              raise ArgumentError, "+options[:order]+ entry #{order.inspect} used an invalid operator #{order.operator}", caller(3)
            end

            case target = order.target
              when Property
                unless @properties.include?(target)
                  raise ArgumentError, "+options[:order]+ entry #{target.inspect} does not map to a property", caller(3)
                end

              when Symbol, String
                unless @properties.named?(target)
                  raise ArgumentError, "+options[:order]+ entry #{target.inspect} does not map to a property", caller(3)
                end

              else
                raise ArgumentError, "+options[:order]+ entry #{order.inspect} does not contain a Property, Symbol or String, but was #{target.class}", caller(3)
            end

          when Symbol, String
            unless @properties.named?(order)
              raise ArgumentError, "+options[:order]+ entry #{order.inspect} does not map to a property", caller(3)
            end

          else
            raise ArgumentError, "+options[:order]+ entry #{order.inspect} of an unsupported object #{order.class}", caller(3)
        end
      end
    end

    # TODO: document this
    # @api private
    def assert_valid_boolean(name, value)
      if value != true && value != false
        raise ArgumentError, "+#{name}+ should be true or false, but was #{value.inspect}", caller(3)
      end
    end

    # TODO: document this
    # @api private
    def assert_valid_other(other)
      unless other.repository == repository
        raise ArgumentError, "+other+ #{self.class} must be for the #{repository.name} repository, not #{other.repository.name}", caller(2)
      end

      unless other.model == model
        raise ArgumentError, "+other+ #{self.class} must be for the #{model.name} model, not #{other.model.name}", caller(2)
      end
    end

    ##
    # Normalize order elements to Query::Direction instances
    #
    #   TODO: needs example
    #
    # @api private
    def normalize_order
      # TODO: should Query::Path objects be permitted?  If so, then it
      # should probably be normalized to a Direction object
      @order = @order.map do |order|
        case order
          when Direction
            order

          when Property
            Direction.new(order)

          when Operator
            target   = order.target
            property = target.kind_of?(Property) ? target : @properties[target]

            Direction.new(property, order.operator)

          when Symbol, String
            Direction.new(@properties[order])

        end
      end
    end

    ##
    # Normalize fields to Property instances
    #
    #   TODO: needs example
    #
    # @api private
    def normalize_fields
      @fields = @fields.map do |field|
        case field
          when Property
            field

          # TODO: mix-in Operator normalization for fields in dm-aggregates
          #when Operator
          #  field

          when Symbol, String
            @properties[field]
        end
      end

      # sort fields based on declared order, appending unmatch fields
      @fields = (@properties & @fields) | @fields
    end

    ##
    # Normalize links to DM::Query::Path
    #
    #   TODO: needs example
    #
    # @api private
    def normalize_links
      @links.map! do |link|
        case link
          when Associations::Relationship
            link

          when Symbol, String
            @relationships[link]
        end
      end

      @links.map! { |r| (i = r.intermediaries).any? ? i : r }
      @links.flatten!
      @links.uniq!
    end

    ##
    # Append conditions to this Query
    #
    #   TODO: needs example
    #
    # @param [Symbol, String, Property, Query::Path, Operator] subject
    #   the subject to match
    # @param [Object] bind_value
    #   the value to match on
    # @param [Symbol] operator
    #   the operator to match with
    #
    # @api private
    def append_condition(subject, bind_value, operator = :eql)
      property = case subject
        when Property
          subject

        when Symbol
          @properties[subject]

        when String
          if subject.include?('.')
            query_path = model
            subject.split('.').each { |m| query_path = query_path.send(m) }
            return append_condition(query_path, bind_value, operator)
          else
            @properties[subject]
          end

        when Operator
          return append_condition(subject.target, bind_value, subject.operator)

        when Query::Path
          @links.concat(subject.relationships)
          subject

        else
          # TODO: move into assert_valid_conditions
          raise ArgumentError, "Condition type #{subject.inspect} not supported", caller(2)
      end

      # TODO: move into assert_valid_conditions
      if property.nil?
        raise ArgumentError, "Clause #{subject.inspect} does not map to a DataMapper::Property", caller(2)
      end

      bind_value = normalize_bind_value(property, bind_value)

      # TODO: move into assert_valid_conditions
      if operator == :not && bind_value.kind_of?(Array) && bind_value.empty?
        raise ArgumentError, "Cannot use 'not' operator with a bind value that is an empty Array for #{property}", caller(2)
      end

      @conditions << [ operator, property, bind_value ]
    end

    # TODO: make this typecast all bind values that do not match the
    # property primitive

    # TODO: document this
    #   TODO: needs example
    # @api private
    def normalize_bind_value(property_or_path, bind_value)
      if bind_value.kind_of?(Proc)
        bind_value = bind_value.call
      end

      case property_or_path
        when Query::Path
          bind_value = normalize_bind_value(property_or_path.property, bind_value)

        when Property
          if property_or_path.custom?
            bind_value = property_or_path.type.dump(bind_value, property_or_path)
          end
      end

      bind_value.kind_of?(Array) && bind_value.size == 1 ? bind_value.first : bind_value
    end

    # TODO: document this
    #   TODO: needs example
    # @api private
    def reset_memoized_vars
      @bind_values = @key_property_indexes = nil

      if defined?(@inheritance_property_index)
        remove_instance_variable(:@inheritance_property_index)
      end
    end

    ##
    # Extract arguments for #slice an #slice! and return offset and limit
    #
    # @param [Integer, Array(Integer), Range] *args the offset,
    #   offset and limit, or range indicating first and last position
    #
    # @return [Integer] the offset
    # @return [Integer,NilClass] the limit, if any
    #
    # @api private
    def extract_slice_arguments(*args)
      first_arg, second_arg = args

      if args.size == 2 && first_arg.kind_of?(Integer) && second_arg.kind_of?(Integer)
        return first_arg, second_arg
      elsif args.size == 1
        if first_arg.kind_of?(Integer)
          return first_arg, 1
        elsif first_arg.kind_of?(Range)
          offset = first_arg.first
          limit  = first_arg.last - offset
          limit += 1 unless first_arg.exclude_end?
          return offset, limit
        end
      end

      raise ArgumentError, "arguments may be 1 or 2 Integers, or 1 Range object, was: #{args.inspect}", caller(1)
    end

    # TODO: document this
    # @api private
    def get_relative_position(offset, limit)
      new_offset = self.offset + offset

      if limit <= 0 || (self.limit && new_offset + limit > self.offset + self.limit)
        raise RangeError, "offset #{offset} and limit #{limit} are outside allowed range"
      end

      return new_offset, limit
    end

    ##
    # Return true if +other+'s is equivalent or equal to +self+'s
    #
    # @param [Query] other
    #   The Resource whose attributes are to be compared with +self+'s
    # @param [Symbol] operator
    #   The comparison operator to use to compare the attributes
    #
    # @return [TrueClass, FalseClass]
    #   The result of the comparison of +other+'s attributes with +self+'s
    #
    # @api private
    def cmp?(other, operator)
      unless repository.send(operator, other.repository)
        return false
      end

      unless model.send(operator, other.model)
        return false
      end

      unless fields.to_set.send(operator, other.fields.to_set)
        return false
      end

      unless links.to_set.send(operator, other.links.to_set)
        return false
      end

      sort_conditions = lambda do |(op, property, bind_value)|
        # stringify conditions to allow comparison of raw vs. normal conditions
        if op == :raw
          [ op.to_s, property, *bind_value ].join(0.chr)
        else
          [ op.to_s, property.model, property.name.to_s, bind_value ].join(0.chr)
        end
      end

      # TODO: update Property#<=> to sort on model and name
      unless conditions.sort_by(&sort_conditions).send(operator, other.conditions.sort_by(&sort_conditions))
        return false
      end

      unless order.send(operator, other.order)
        return false
      end

      unless offset.send(operator, other.offset)
        return false
      end

      unless limit.send(operator, other.limit)
        return false
      end

      unless reload?.send(operator, other.reload?)
        return false
      end

      unless unique?.send(operator, other.unique?)
        return false
      end

      unless add_reversed?.send(operator, other.add_reversed?)
        return false
      end

      true
    end
  end # class Query
end # module DataMapper

dir = Pathname(__FILE__).dirname.expand_path / 'query'

require dir / 'direction'
require dir / 'operator'
require dir / 'path'
