class AddLocaleToUsers < ActiveRecord::Migration
  def self.up
    change_table :users do |t|
      t.string  :locale
    end
  end

  def self.down
    change_table :users do |t|
      t.remove  :locale
    end
  end
end
