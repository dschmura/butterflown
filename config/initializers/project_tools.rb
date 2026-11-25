# The fork seam for project tools: build a tool's surface first, then register it here.
# See app/docs/developer/project-tools.md. The base template ships only :docs.
Rails.application.config.to_prepare do
  ProjectTools::Registry.reset!

  ProjectTools::Registry.register(
    key: :docs,
    path_helper: :workspace_project_resources_path,
    default_enabled: true
  )
end
