class Memory
  # Who a memory or resource is credited to: a name, a former member with or without one, or no one.
  # An anonymous credit carries no former-member label, which would say something about its author.
  Credit = Data.define(:name, :former_member) do
    def self.of(person, community:, anonymous: false)
      return new(name: nil, former_member: false) if anonymous

      membership = community.memberships.find_by(user: person)
      return new(name: person.full_name, former_member: false) if membership&.kept?

      new(name: (person.full_name unless membership&.name_removed?), former_member: true)
    end

    def former_member? = former_member
    def anonymous? = name.nil? && !former_member
  end
end
