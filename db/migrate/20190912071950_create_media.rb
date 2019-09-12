class CreateMedia < ActiveRecord::Migration[6.0]
  def change
    create_table :media do |t|
      t.string :title
      t.int :year

      t.timestamps
    end
  end
end