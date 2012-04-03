require 'active_record'
require 'active_record/fixtures'
require 'test_helper'
require 'polymorphic'

require 'lib/activerecord_test_case.rb'

load 'fixtures/schema.rb'

ActiveRecord::Fixtures.create_fixtures(
  "#{File.expand_path(File.dirname(__FILE__))}/fixtures/",
  ActiveRecord::Base.connection.tables)

class Car < ActiveRecord::Base
  has_and_belongs_to_many :streets, :join_table => "street_cars"
end

class Bike < ActiveRecord::Base
  has_and_belongs_to_many :streets, :join_table => "street_bikes"
end

class Street < ActiveRecord::Base
  has_and_belongs_to_many :cars, :join_table => "street_cars"
  has_and_belongs_to_many :bikes, :join_table => "street_bikes"
  polymorphic :vehicles, :cars, :bikes
end

class Meat < ActiveRecord::Base
end
class Veg < ActiveRecord::Base
end
class Dish < ActiveRecord::Base
  has_one :meat
  has_one :veg
  polymorpic :ingredient
end

class PolymorphicTest < ActiveSupport::TestCase

  test "association works" do
    assert s = Street.new
    assert_equal false, s.vehicles.nil?
    assert_equal [], s.vehicles
  end

  test "assignent works" do
    s = Street.first
    assert s.vehicles
    assert s.vehicles << Car.first
    assert_equal 1, s.vehicles.size
    assert s.vehicles << Bike.first
    assert_equal 2, s.vehicles.size
    assert_equal Car.first, s.vehicles.first
    assert_equal Bike.first, s.vehicles.last
  end

  test "deletion works" do
    s = Street.new
    assert s.vehicles << Car.first
    assert s.vehicles.delete_all
    assert_equal [], s.vehicles
  end

  test "inspect works" do
    s = Street.new
    assert_nothing_raised { s.vehicles.inspect }
  end

  test "pop works" do
    s = Street.first
    vehicles_size = s.vehicles.size
    assert vehicle = s.vehicles.pop
    assert vehicle.is_a?(Bike)
    assert_equal vehicles_size - 1, s.vehicles.size
  end

  test "clear works" do
    s = Street.new
    assert s.vehicles << Bike.first
    assert_not_equal 0, s.vehicles.size
    assert_nothing_raised { s.vehicles.clear }
    assert_equal [], s.vehicles
  end

  test "has one association" do
    assert f = Dish.new
    assert f.ingredient
    assert f.ingredient = Veg.new
    assert f.save!
  end

end
