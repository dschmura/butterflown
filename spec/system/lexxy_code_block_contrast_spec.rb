# frozen_string_literal: true

require "rails_helper"

RSpec.describe "A code block in the rich-text editor", type: :system do
  it "highlights its syntax at AAA in both themes" do
    user = create(:user)
    workspace = user.workspaces.sole
    project = create(:project, workspace: workspace, created_by: user)
    document = create(:document, body: %(<pre data-language="ruby">def greet(name)\n  puts "Hello, \#{name}!" # say hi\nend</pre>))
    resource = create(:resource, project: project, resourceable: document, created_by: user)
    sign_in_via_form(user)
    visit edit_workspace_project_resource_path(workspace, project, resource)

    expect(page).to have_css("lexxy-editor .code-token__function", text: "greet")
    expect(page).to have_css("lexxy-editor .code-token__comment", text: "# say hi")
    expect_aaa_in_both_themes(include: "lexxy-editor")
  end
end
