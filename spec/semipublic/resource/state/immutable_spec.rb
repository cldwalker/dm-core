require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper'))

describe DataMapper::Resource::State::Immutable do
  before :all do
    class ::Author
      include DataMapper::Resource

      property :id,     Serial
      property :name,   String
      property :active, Boolean, :default => true
      property :coding, Boolean, :default => true

      belongs_to :parent, self, :required => false
    end

    @model = Author
  end

  before do
    @parent  = @model.create(:name => 'John Doe')

    @resource = @model.create(:name => 'Dan Kubb', :parent => @parent)
    @resource = @model.first(@model.key.zip(@resource.key).to_hash.merge(:fields => [ :name, :parent_id ]))

    @state = @resource.persisted_state
    @state.should be_kind_of(DataMapper::Resource::State::Immutable)
  end

  describe '#commit' do
    subject { @state.commit }

    supported_by :all do
      it 'should be a no-op' do
        should equal(@state)
      end
    end
  end

  describe '#delete' do
    subject { @state.delete }

    supported_by :all do
      it 'should raise an exception' do
        method(:subject).should raise_error(DataMapper::ImmutableError, 'Immutable resource cannot be deleted')
      end
    end
  end

  describe '#get' do
    subject { @state.get(@key) }

    supported_by :all do
      describe 'with an unloaded property' do
        before do
          @key = @model.properties[:id]
        end

        it 'should raise an exception' do
          method(:subject).should raise_error(DataMapper::ImmutableError, 'Immutable resource cannot be lazy loaded')
        end
      end

      describe 'with an unloaded relationship' do
        before do
          @key = @model.relationships[:parent]
        end

        it 'should return value' do
          should == @parent
        end
      end

      describe 'with a loaded subject' do
        before do
          @key = @model.properties[:name]
        end

        it 'should return value' do
          should == 'Dan Kubb'
        end
      end
    end
  end

  describe '#set' do
    before do
      @key   = @model.properties[:name]
      @value = @key.get!(@resource)
    end

    subject { @state.set(@key, @value) }

    supported_by :all do
      it 'should raise an exception' do
        method(:subject).should raise_error(DataMapper::ImmutableError, 'Immutable resource cannot be modified')
      end
    end
  end
end
