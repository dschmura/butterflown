require "rails_helper"

# A read that skips Memory.visible_to can leak a private memory; parsed, so a comment can't pass it.
# See /docs/developer/memory-visibility.
RSpec.describe "Code smell: memories are read through visible_to" do
  constants = %i[Memory MemoryResource MemoryAccess Tag]
  calls = %i[memories accesses tags]
  # The exit page is the one other door: a removed member's own memories, for 90 days.
  readers = %i[visible_to on_exit_page_of]

  # Files that define the rule, or only build new memories. Reviewed; add with a reason.
  allowed = {
    "app/models/memory.rb" => "defines the model and its associations",
    "app/models/memory/visibility.rb" => "defines visible_to",
    "app/models/memory_access.rb" => "defines the model",
    "app/models/memory_resource.rb" => "defines the model",
    "app/models/memory_resource/tagging.rb" => "declares the association and creates tags",
    "app/models/memory_resource/visibility.rb" => "defines MemoryResource.visible_to",
    "app/models/flag.rb" => "routes, hides and brings back what was flagged; never shows",
    "app/models/memory/moderated.rb" => "declares the flag and reveal associations",
    "app/models/moderation/history.rb" => "finds a member's named memories to count their record; never shows",
    "app/models/memory/credit.rb" => "only opens the Memory namespace",
    "app/models/memory/left_behind.rb" => "defines on_exit_page_of and the purge of private memories left behind",
    "app/models/user/account_deletion.rb" => "deletes the departing author's own private memories; never shows",
    "app/jobs/left_behind_memories_sweep_job.rb" => "calls the purge of private memories left behind; never shows",
    "app/models/membership/departure.rb" => "unnames pending tags when someone goes; writes, never shows",
    "app/models/tag.rb" => "defines the model and Tag.visible_to",
    "app/models/workspace/memories.rb" => "declares the association and builds new memories"
  }

  ruby_of = lambda do |file, source|
    file.end_with?(".erb") ? ActionView::Template::Handlers::ERB::Erubi.new(source).src : source
  end

  # A mention is gated when it is the receiver of a reader, or sits anywhere inside policy_scope(...).
  offenders = lambda do |sources|
    sources.flat_map do |file, source|
      next [] if allowed.key?(file)

      found = []
      visit = lambda do |node, ancestors|
        mention =
          case node
          when Prism::ConstantReadNode then constants.include?(node.name)
          when Prism::SymbolNode then calls.include?(node.unescaped.to_sym)
          when Prism::CallNode then calls.include?(node.name)
          end
        if mention
          parent = ancestors.last
          gated = (parent.is_a?(Prism::CallNode) && readers.include?(parent.name) && parent.receiver.equal?(node)) ||
            ancestors.any? { |a| a.is_a?(Prism::CallNode) && a.name == :policy_scope && a.receiver.nil? }
          found << "#{file}:#{node.location.start_line}" unless gated
        end
        node.compact_child_nodes.each { |child| visit.call(child, ancestors + [ node ]) }
      end
      visit.call(Prism.parse(ruby_of.call(file, source)).value, [])
      found
    end
  end

  watched_sources = lambda do
    Dir[Rails.root.join("{app,lib}/**/*.{rb,erb}")].sort.to_h { |file| [ file.delete_prefix("#{Rails.root}/"), File.read(file) ] }
  end

  it "finds no read of memories that skips visible_to" do
    found = offenders.call(watched_sources.call)

    expect(found).to be_empty,
      "These lines read memories without Memory.visible_to or policy_scope:\n  #{found.join("\n  ")}\n" \
      "Read through `@workspace.memories.visible_to(Current.user)` or `policy_scope(...)`, or add the file " \
      "to `allowed` here with a reason."
  end

  it "catches every read it is written against, including ones dressed up to look gated" do
    planted = [
      "Memory.find(params[:id])",
      "Memory.unscoped.find(id) # visible_to",
      "Memory.find(1); label = \"visible_to\"",
      "@workspace.memories.visible_to(user).or(@workspace.memories)",
      "Workspace.includes(:memories)",
      "Workspace.joins(:memories)",
      "memories.count",
      "workspace.method(:memories).call",
      "model = Memory",
      "MemoryResource.where(memory_id: ids)",
      "MemoryAccess.where(user: user)",
      "memory.accesses.pluck(:user_id)",
      "Tag.where(tagged_user: user)",
      "resource.tags.pending"
    ]
    files = planted.each_with_index.to_h { |line, i| [ "app/models/x#{i}.rb", "#{line}\n" ] }
    files["app/views/x/index.html.erb"] = "<% @workspace.memories.each do |memory| %><% end %>\n"

    caught = offenders.call(files).map { |offender| offender.split(":").first }.uniq

    expect(caught).to match_array(files.keys)
  end

  it "lets the sanctioned reads through" do
    sanctioned = {
      "app/controllers/x_controller.rb" => <<~RUBY,
        @memories = @workspace.memories.visible_to(Current.user)
        @memory = policy_scope(@workspace.memories).find(params[:id])
        Memory.visible_to(user).exists?(id)
        Tag.visible_to(user).where(tagged_user: user)
        Memory.on_exit_page_of(user).exists?(id)
        MemoryResource.visible_to(user).exists?(id)
        @workspace.memories
          .visible_to(Current.user)
      RUBY
      "app/views/x/index.html.erb" => "<% @workspace.memories.visible_to(Current.user).each do |memory| %><% end %>\n"
    }

    expect(offenders.call(sanctioned)).to be_empty
  end

  it "lists only files that exist" do
    expect(allowed.keys.reject { |file| Rails.root.join(file).exist? }).to be_empty
  end
end
