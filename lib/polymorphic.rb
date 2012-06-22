class ActiveRecord::Base

  class PolymorphicRecordMismatch < StandardError;end

  ##
  # polymorphic allows to 'join' several has_many/has_one definitions into one
  # 'polymorphic' association, which behaves much likes rails :polymorphic =>
  # true, but allows to have real accessors that can be verified on database
  # level. One 'polymorphic' association can only join either has_many OR
  # has_one associations, not both. belongs_to relations can not be polymorphic
  # either.
  #
  # @example Example declaration
  #   class Meal < ActiveRecord::Base
  #     has_many :apples
  #     has_many :peas
  #     has_many :cherries
  #     polymorphic :vegetables, :apples, :peas, :cherries
  #
  #     has_one :meat
  #     has_one :salad
  #     polymorphic :main_ingridient, :meat, :salad
  #   end
  #
  # @example Example Usage
  #   m = Meal.new
  #   a = Apple.find(1)
  #   m.vegetables << a
  #   m.vegetables # => [<Apple id:1>]
  #
  # @param [Symbol] name Name of the association to be created
  # @param [Array<Symbol>] list of associations to be joined
  # @raises ArgumentError if Association is already defined
  # @raises ArgumentError if Associations are mixed has_many/has_one

  def self.polymorphic(name, *assocs)
	  # Remove hash from assocs, which could contain options
		options = assocs.last.is_a?(Hash) ? assocs.pop : {}

    raise "#{name.inspect} already defined" if self.respond_to?(name)
    reflectioas = self.reflections

    # determine if the association will be a colection or not.
    if assocs.all? {|oth| reflections[oth.to_sym].collection? }
      is_collection = true
    elsif assocs.all? {|oth| not reflections[oth.to_sym].collection? }
      is_collection = false
    else
      raise "#{name.inspect} does contain mixed collections and non collections"
    end

		# To use polymorphic associtaion in the reflections, we add the first
		# (or the one which is set in options) association to the reflections
		# table
		assoc = reflections[options[:default]] || reflections[assocs.first]
		create_reflection(assoc.macro, name,
		  assoc.options.merge({:class_name => assoc.class_name}),
			assoc.active_record)

    # define 'getter' method to create a new PolyProxy object and return it.
    define_method(name.to_sym) do
      @proxies ||= {}
      @proxies[name.to_sym] ||= PolyProxy.new(self, assocs, is_collection)
      return @proxies[name.to_sym]
    end

    # define 'setter' method to call PolyProxy#execute_set
    define_method("#{name}=") do |arg|
      @proxies ||= {}
      @proxies[name.to_sym] ||= PolyProxy.new(self, assocs, is_collection)
      return @proxies[name.to_sym].execute_set(arg)
    end
  end


  ##
  # PolyProxy is a proxy class that behaves very much like AssociationProxy and
  # provides and interface that will handle dealing with pseudo polymorphic
  # associations and will automatically join and distribute things over all
  # associations.

  class PolyProxy
    METHOD_BLACKLIST = [ :find, :create, :create!, :build, :build!, :concat ]
    ARRAY_EDIT_ACTIONS = [:reverse!, :rotate!, :sort!, :sort_by!, :collect!,
      :map!, :select!, :reject!, :slice!, :uniq!, :compact!, :flatten!,
      :shuffle!, :extract_options!, :uniq_by!]

    ##
    # create a new PolyProxy. Every call done to this object will automatically
    # distribute the call to the apropriate underlying function.
    #
    # @param [ActiveRecord::Base] target The instance where the polymorphism is
    #        defined upon.
    # @param [Array<Symbol>] args An array of associations joined via this
    #         object.
    # @param [Bool] is_collection whether the association is a collection or
    #         not.

    def initialize(target, args, is_collection)
      @target = target
      @assocs = args
      @collection = is_collection
      @ary = nil
    end

    # Code taken from AssociationProxy which will get rid of all unneeded
    # methods for this Object.

    instance_methods.each { |m|
      undef_method m unless m.to_s =~ /^(?:nil\?|send|object_id|to_a)$|^__|^respond_to/
    }

    ##
    # overloading of class will make the object behave like the object it's
    # proxying for.

    def class
      return Array if @collection
      return get_single_object.class
    end

    ##
    # get_single_object will get the single object that currently is defined
    # in this polymorphic association.
    # @return [ActiveRecord::Base] the current object defined.

    def get_single_object
      raise "only be used if collection = false" if @collection
      return @assocs.map {|o| @target.send(o) }.compact.first
    end

    ##
    # with_associations allows to loop over all associations defined for
    # this PolyProxy object and then yields each find accordingly. If
    # an array is associated, it's cache will automatically be reloaded.
    #
    # @yield [ActiveRecord::Base] The result of the assocation
    # @yield [Class] the name of the class associated with this association
    # @yield [String] The name of the String

    def with_associations
      reflects = @target.reflections
      @assocs.each do |assoc|
        yield @target.send(assoc),
          reflects[assoc].class_name.constantize,
          assoc
      end
      load_array(true) if @collection
    end

    ##
    # Detects the association corresponding to the given object and returns
    # it's name.
    #
    # @param [ActiveRecord::Base] obj the object to find an Association for.
    # @return [Symbol] returns the name of the assocation or nil

    def detect_association_for(obj)
      reflects = @target.reflections

      res = @assocs.detect do |oth|
        obj.is_a? reflects[oth.to_sym].class_name.constantize
      end

      return nil unless res
      return reflects[res].name
    end

    def inspect
      return @collection ? load_array.inspect : get_single_object.inspect
    end

    def nil?
      return false if @collection
      return get_single_object.nil?
    end

    # overloaded push to allow pushing into array instantiated classes. Behaves
    # like every normal push, but automatically reloads data if needed

    def <<(other)
      raise "only be used if collection = true" unless @collection
      load_array

      # if object does not belong to the association, return the current array
      return self unless other_assoc = detect_association_for(other)

      @target.send(other_assoc).send("<<", other)
      return load_array(true)
    end
    alias_method :push, :<<


    ##
    # to_ary function overloaded to treat both collections and non-collections
    # @return [Array] an array of all objects associated with this array

    def to_ary
      return load_array.dup if @collection
      return [get_single_obj]
    end

    ##
    # clear deletes all elements from all associations
    # @return [PolyProxy] returns self.

    def clear
      delete_all
      return self
    end

    ##
    # forces all associations to be reloaded
    def reload
      with_associations {|t,_| t.reload}
    end

    ##
    # deletes all from associations
    def delete_all
      with_associations {|t,_| t.delete_all}
    end

    ##
    # removes all objects from associations and destroys the objects as well.
    def destroy_all
      with_associations {|t,_| t.destroy_all}
    end

    ##
    # records_with_assoc uses the given records array and yields the records
    # sorted by association.
    #
    # @yield [ActiveRecord::Base] current result of association
    # @yield [Array<ActiveRecord::Base>] current objects belonging to this class
    # @yield [Symbol] name of the current association
    # @return [PolyProxy] returns self

    def records_with_assoc(records)
      with_associations do |t,klass,assoc|
        yield t, records.select {|r| r.is_a? klass}, assoc
        # t.reload if @collection
      end
      load_array(true) if @collection
      return self
    end

    ##
    # deletes the given records from all associations using records_with_assoc
    # @param [Array<ActiveRecord::Base>] records to be deleted.

    def delete(records)
      records_with_assoc(records) {|t,r,_| t.delete([r])}
    end

    ##
    # deletes the given records from all associations using records_with_assoc
    # and destroyes the objects itself as well.
    # @param [Array<ActiveRecord::Base>] records to be deleted.

    def destroy(records)
      records_with_assoc(records) {|t,r,_| t.destroy([r])}
    end


    ##
    # extended respond to which is able to check whether itself or any of it's
    # proxied objects supports the called methods.
    # @param [Symbol] name The method to check for existance
    # @return True or False

    def respond_to?(name)
      return true if super(name)

      if @collection and load_array and @ary.respond_to? name
        return true
      end

      if !@collection and obj = get_single_object and obj.respond_to? name
        return true
      end
    end

    ##
    # method_missing is the heart piece of PolyProxy, allowing calls to be
    # proxied to the real associations.
    #
    # @param [Symbol] name the name of the method called
    # @param [Array] args arguments to the method
    # @param [Proc] blk optionally a block that has been passed

    def method_missing(name, *args, &blk)
      return super(name,*args) unless respond_to?(name.to_sym)

      if METHOD_BLACKLIST.include?(name.to_sym)
        raise "Method #{name.inspect} is not supported."
      end

      if @collection
        if load_array and @ary.respond_to? name
          return @ary.send(name, *args, &blk) unless
            ARRAY_EDIT_ACTIONS.include?(name.to_sym)
          return execute_set(to_ary.send(name, *args, &blk))
        end
      end

      obj = get_single_object
      if obj.respond_to? name
        return obj.send(name, *args, &blk)
      end
    end


    ##
    # load_array handles the loading of the internal array cache, so data
    # doesn't need to be loaded by every action for the same model. unless
    # the force boolean is set to true, the cache is used instead.
    #
    # @param [Bool] force if this is set to true, reload always happens,
    #        bypassing the internal cache.

    def load_array(force=false)
      raise "can only be used if collection = true" unless @collection

      @ary = nil if force
      @ary ||= @assocs.map {|o| @target.send(o) }.flatten

      return @ary
    end

    ##
    # execute_set will handle assignment operations as used by ruby code to
    # change the underlying proxied Object.

    def execute_set(arg)
      if (@collection and !arg.is_a? Array) or
        (!@collection and arg.is_a? Array)
        raise PolymorphicRecordMismatch,
          "tried to mix Array and single objects during assignment"
      end

      if @collection
        records_with_assoc(arg) {|_,rec,name| @target.send("#{name}=", rec) }
        load_array
        return self
      end

      records_with_assoc([arg]) do |_,rec,name|
        @target.send("#{name}=", rec.first)
      end
      return self
    end
  end
end
