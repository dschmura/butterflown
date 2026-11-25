# frozen_string_literal: true

# Whether a path is in the repo, for doc checks that must name only real files or directories.
module TrackedPaths
  def tracked_files
    @tracked_files ||= IO.popen(CleanGitEnv::HASH, [ "git", "ls-files", "-z" ], chdir: Rails.root.to_s, &:read).split("\0")
  end

  def tracked_path?(path)
    tracked_paths.include?(path.delete_suffix("/"))
  end

  private

  def tracked_paths
    @tracked_paths ||= begin
      files = tracked_files
      (files + files.flat_map { |file| Pathname(file).dirname.descend.map(&:to_s) }).to_set
    end
  end
end

RSpec.configure do |config|
  config.include TrackedPaths
end
