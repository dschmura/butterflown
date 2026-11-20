require "rails_helper"

# Action Text attachments have no content-type allowlist, so a BMP/ICO/PSD can reach a document body (GHSA-xr9x-r78c-5hrm).
# Libvips refuses those types, so they render as a file chip and the page never asks for a variant it cannot make.
RSpec.describe "Document with a blocked-loader attachment", type: :request do
  def document_resource_with_signed_in_creator
    user = create(:user)
    workspace = create(:workspace)
    create(:membership, :owner, user: user, workspace: workspace)
    project = create(:project, workspace: workspace, created_by: user)
    project.project_memberships.find_by!(user: user)
    resource = create(:resource, project: project, created_by: user, resourceable: create(:document))
    Current.workspace = workspace
    Current.project = project
    sign_in(user)
    resource
  end

  def attach_to_document(resource, fixture, content_type, alt: nil)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: Rails.root.join("spec/fixtures/files", fixture).open,
      filename: fixture,
      content_type: content_type
    )
    alt_attribute = alt && %( alt="#{ERB::Util.html_escape(alt)}")
    resource.resourceable.update!(
      body: %(<action-text-attachment sgid="#{blob.attachable_sgid}"#{alt_attribute}></action-text-attachment>)
    )
  end

  def rendered_figure(resource)
    get workspace_project_resource_path(resource.project.workspace, resource.project, resource)
    expect(response).to have_http_status(:ok)
    Nokogiri::HTML(response.body).at_css("figure.attachment")
  end

  it "renders a blocked-loader attachment as a file chip, with no image to fetch" do
    resource = document_resource_with_signed_in_creator
    attach_to_document(resource, "unfuzzed.bmp", "image/bmp")

    figure = rendered_figure(resource)

    expect(figure["class"]).to include("attachment--file")
    expect(figure.at_css("img")).to be_nil
  end

  it "still previews an attachment libvips can safely transform" do
    resource = document_resource_with_signed_in_creator
    attach_to_document(resource, "avatar.png", "image/png")

    figure = rendered_figure(resource)

    expect(figure["class"]).to include("attachment--preview")
    expect(figure.at_css("img")).to be_present
    expect(figure.at_css("img")["alt"]).to eq("")
  end

  it "renders the alternative text the author wrote in place of the filename" do
    resource = document_resource_with_signed_in_creator
    attach_to_document(resource, "avatar.png", "image/png", alt: "A red canoe on a still lake")

    expect(rendered_figure(resource).at_css("img")["alt"]).to eq("A red canoe on a still lake")
  end
end
