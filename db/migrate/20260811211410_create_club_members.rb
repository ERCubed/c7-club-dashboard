class CreateClubMembers < ActiveRecord::Migration[8.1]
  def change
    create_table :club_members do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :commerce7_customer_id, null: false
      t.string :name
      t.string :email
      t.string :club_tier
      t.datetime :joined_at

      t.timestamps
    end
    add_index :club_members, [ :tenant_id, :commerce7_customer_id ], unique: true
    add_index :club_members, [ :tenant_id, :club_tier ]
  end
end
