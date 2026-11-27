require "rails_helper"

RSpec.describe MemoryResource, type: :model do
  let(:memory) { create(:memory) }

  it "needs words when it is a written reflection" do
    resource = build(:memory_resource, memory: memory, kind: "written_reflection", body: " ")

    expect(resource.tap(&:validate).errors).to be_added(:body, :blank)
  end

  it "needs an image when it is a photo" do
    resource = build(:memory_resource, memory: memory, kind: "photo", body: nil)

    expect(resource.tap(&:validate).errors).to be_added(:photo, :blank)
  end

  it "accepts a photo with a caption" do
    resource = build(:memory_resource, :photo, memory: memory, body: "Dock, 1991")

    expect(resource).to be_valid
  end

  it "refuses a photo that isn't an image" do
    resource = build(:memory_resource, memory: memory, kind: "photo", body: nil)
    resource.photo.attach(io: StringIO.new("%PDF-1.4"), filename: "notes.pdf", content_type: "application/pdf")

    expect(resource.tap(&:validate).errors.of_kind?(:photo, :content_type_invalid)).to be true
  end

  it "refuses a kind it doesn't know" do
    resource = build(:memory_resource, memory: memory, kind: "hologram")

    expect(resource.tap(&:validate).errors.of_kind?(:kind, :inclusion)).to be true
  end

  it "refuses a photo riding on a written reflection" do
    resource = build(:memory_resource, :photo, memory: memory, kind: "written_reflection", body: "Words.")

    expect(resource.tap(&:validate).errors).to be_added(:photo, :only_on_a_photo)
  end

  it "keeps a short content warning, and refuses a long one" do
    expect(build(:memory_resource, memory: memory, content_warning: "x" * 60)).to be_valid
    expect(build(:memory_resource, memory: memory, content_warning: "x" * 61)).not_to be_valid
  end

  it "stores the words encrypted" do
    resource = create(:memory_resource, memory: memory, body: "The lake froze the winter I arrived.")

    stored = MemoryResource.connection.select_value("SELECT body FROM memory_resources WHERE id = #{resource.id}")

    expect(stored).to be_present
    expect(stored).not_to include("lake")
    expect(resource.reload.body).to eq("The lake froze the winter I arrived.")
  end

  it "calls a resource from someone other than the author a perspective" do
    other = create(:membership, workspace: memory.workspace).user

    expect(build(:memory_resource, memory: memory, contributor: memory.author)).not_to be_perspective
    expect(build(:memory_resource, memory: memory, contributor: other)).to be_perspective
  end
end
