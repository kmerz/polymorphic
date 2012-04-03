ActiveRecord::Schema.define do
  create_table "cars", :force => true do |t|
	  t.column "name", :text
		t.column "id", :integer
  end

	create_table "street_cars", :force => true do |t|
		t.column "street_id", :integer
		t.column "car_id", :integer
	end

	create_table "street_bikes", :force => true do |t|
		t.column "street_id", :integer
		t.column "bike_id", :integer
	end

  create_table "bikes", :force => true do |t|
	  t.column "name", :text
		t.column "id", :integer
  end

  create_table "streets", :force => true do |t|
	  t.column "name", :text
		t.column "id", :integer
  end

  create_table "dishes", :force => true do |t|
    t.column "name", :text
    t.column "id", :integer
  end

  create_table "meats", :force => true do |t|
    t.column "name", :text
    t.column "id", :integer
  end

  create_table "vegs", :force => true do |t|
    t.column "name", :text
    t.column "id", :integer
  end
end
