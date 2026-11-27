FactoryBot.define do
  factory :memory do
    workspace
    author factory: :user

    # A memory is born through Workspace#post_memory, by a member, with at least one resource.
    after(:build) do |memory|
      unless memory.workspace.memberships.kept.exists?(user: memory.author)
        create(:membership, user: memory.author, workspace: memory.workspace)
      end
      if memory.resources.empty?
        memory.resources.build(kind: "written_reflection", body: "A memory.", contributor: memory.author)
      end
    end
  end

  factory :memory_resource do
    memory
    contributor { memory.author }
    kind { "written_reflection" }
    body { "A reflection." }

    trait :photo do
      kind { "photo" }
      after(:build) do |resource|
        resource.photo.attach(io: File.open(Rails.root.join("spec/fixtures/files/avatar.png")), filename: "photo.png", content_type: "image/png")
      end
    end
  end
end
