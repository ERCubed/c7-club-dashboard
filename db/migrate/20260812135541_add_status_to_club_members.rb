class AddStatusToClubMembers < ActiveRecord::Migration[8.1]
  def change
    # Commerce7 club memberships carry a status (Active/Cancelled/On Hold);
    # without it, tier breakdowns and at-risk queries can't exclude lapsed members.
    add_column :club_members, :status, :string
    add_index :club_members, [ :tenant_id, :status ]
  end
end
