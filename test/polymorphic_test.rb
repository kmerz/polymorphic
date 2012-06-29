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

class Bicycle < ActiveRecord::Base
  has_and_belongs_to_many :streets, :join_table => "street_bicycle"
end

class Bike < ActiveRecord::Base
  has_and_belongs_to_many :streets, :join_table => "street_bikes"
end

class Street < ActiveRecord::Base
  has_and_belongs_to_many :cars, :join_table => "street_cars"
  has_and_belongs_to_many :bikes, :join_table => "street_bikes"
  has_and_belongs_to_many :bicycle, :join_table => "street_bicycle"
  polymorphic :vehicles, :cars, :bikes
end

class Meat < ActiveRecord::Base
end

class Veg < ActiveRecord::Base
end

class Dish < ActiveRecord::Base
  has_one :meat
  has_one :veg
  polymorphic :ingredient, :meat, :veg
end

class PolymorphicTest < ActiveSupport::TestCase

  test "polymorphic works with has_many associations" do
    assert s = Street.new
    assert_equal false, s.vehicles.nil?
    assert_equal [], s.vehicles
  end

  test "polymorphic works only with polymorphed associations" do
    assert s = Street.new
    assert_equal false, s.vehicles.nil?
    assert_equal [], s.vehicles
    s.vehicles << Bicycle.new
    assert_equal [], s.vehicles
  end

  test "assignent works with has_many associations" do
    s = Street.first
    assert s.vehicles
    assert s.vehicles << Car.first
    assert_equal 1, s.vehicles.size
    assert s.vehicles << Bike.first
    assert_equal 2, s.vehicles.size
    assert_equal Car.first, s.vehicles.first
    assert_equal Bike.first, s.vehicles.last
  end

  test "deletion works with has_many associations" do
    s = Street.new
    assert s.vehicles << Car.first
    assert s.vehicles.delete_all
    assert_equal [], s.vehicles
  end

  test "inspect works with has_many associations" do
    s = Street.new
    assert_nothing_raised { s.vehicles.inspect }
  end

  test "pop works with has_many associations" do
    s = Street.first
    vehicles_size = s.vehicles.size
    assert vehicle = s.vehicles.pop
    assert vehicle.is_a?(Bike)
    assert_equal vehicles_size - 1, s.vehicles.size
  end

  test "clear works with has_many associations" do
    s = Street.new
    assert s.vehicles << Bike.first
    assert_not_equal 0, s.vehicles.size
    assert_nothing_raised { s.vehicles.clear }
    assert_equal [], s.vehicles
  end

  test "polymorphic association works with has one association" do
    assert f = Dish.new
    assert f.ingredient
    v = Veg.create
    m = Meat.create
    assert f.ingredient = v
    assert_equal v, f.ingredient
    assert f.save!
    assert f.ingredient = m
    assert f.save!
    assert_equal m, f.ingredient
  end

end
