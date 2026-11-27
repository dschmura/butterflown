require "rails_helper"

RSpec.describe MemoryAccess, type: :model do
  let(:memory) { create(:memory, visibility: "specific_people") }

  it "names a current member of the memory's community" do
    person = create(:membership, workspace: memory.workspace).user

    expect(MemoryAccess.new(memory: memory, user: person)).to be_valid
  end

  it "refuses someone outside the community, or who has left it" do
    outsider = create(:user)
    leaver = create(:membership, :deactivated, workspace: memory.workspace).user

    [ outsider, leaver ].each do |person|
      expect(MemoryAccess.new(memory: memory, user: person).tap(&:validate).errors).to be_added(:user, :not_a_member)
    end
  end

  it "names a person once per memory, in the database too" do
    person = create(:membership, workspace: memory.workspace).user
    MemoryAccess.create!(memory: memory, user: person)

    expect(MemoryAccess.new(memory: memory, user: person)).not_to be_valid
    expect { MemoryAccess.new(memory: memory, user: person).save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "goes with the memory" do
    person = create(:membership, workspace: memory.workspace).user
    MemoryAccess.create!(memory: memory, user: person)

    expect { memory.destroy! }.to change(MemoryAccess, :count).by(-1)
  end
end
