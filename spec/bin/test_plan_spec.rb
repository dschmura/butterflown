require "rails_helper"
require "open3"
require "tmpdir"

RSpec.describe "bin/test-plan" do
  let(:repo) { Pathname.new(Dir.mktmpdir) }
  let(:script) { Rails.root.join("bin/test-plan").to_s }

  after { FileUtils.rm_rf(repo) }

  def commit_file(name, body = "x\n")
    repo.join(name).dirname.mkpath
    repo.join(name).write(body)
    scratch_git(repo, "add", name)
    scratch_git(repo, "commit", "-qm", name)
  end

  def test_plan(*args, env: {})
    Open3.capture2e(CleanGitEnv::HASH.merge(env), script, *args, chdir: repo.to_s)
  end

  before do
    scratch_git(repo, "init", "-q", "-b", "main")
    commit_file("spec/i18n_spec.rb")
    scratch_git(repo, "update-ref", "refs/remotes/origin/main", "HEAD")
    scratch_git(repo, "checkout", "-q", "-b", "next")
    commit_file("app/models/x.rb", "class X\nend\n")
    scratch_git(repo, "update-ref", "refs/remotes/origin/next", "HEAD")
    scratch_git(repo, "checkout", "-q", "-b", "work")
  end

  context "with a locale-only branch cut from next while next is ahead of main" do
    before { commit_file("config/locales/en.yml", "en:\n  hi: Hi\n") }

    it "classifies it as locale" do
      out, status = test_plan

      expect(status.exitstatus).to eq(0)
      expect(out.lines(chomp: true)).to eq([ "lanes: locale", "spec/i18n_spec.rb" ])
    end

    it "counts an uncommitted edit, since it runs before the commit" do
      repo.join("app/models/x.rb").write("class X\n  def y = 1\nend\n")

      out, _status = test_plan

      expect(out).to start_with("lanes: full\n")
    end

    it "counts an untracked file" do
      repo.join("app/models/y.rb").write("class Y\nend\n")

      out, _status = test_plan

      expect(out).to start_with("lanes: full\n")
    end

    it "honours --base" do
      out, _status = test_plan("--base", "origin/main")

      expect(out).to include("lanes: full")
    end

    it "writes full and specs to GITHUB_OUTPUT" do
      output = repo.join("github_output")

      _out, status = test_plan("--github-output", env: { "GITHUB_OUTPUT" => output.to_s })

      expect(status.exitstatus).to eq(0)
      expect(output.read.lines(chomp: true)).to eq([ "full=false", "specs=spec/i18n_spec.rb" ])
    end

    it "seeds before running specs, and runs them without coverage instrumentation" do
      out, status = test_plan("--run", "--dry-run")

      expect(status.exitstatus).to eq(0)
      expect(out.lines(chomp: true)).to eq([
        "lanes: locale",
        "RAILS_ENV=test bin/rails db:setup",
        "SKIP_COVERAGE=1 bundle exec rspec spec/i18n_spec.rb"
      ])
    end
  end

  it "is full when a code file is renamed into a docs-lane path" do
    scratch_git(repo, "mv", "app/models/x.rb", "README.md")
    scratch_git(repo, "commit", "-qm", "rename")

    out, _status = test_plan

    expect(out).to start_with("lanes: full\n")
  end

  describe "--green-skip" do
    let(:fakebin) { Pathname.new(Dir.mktmpdir) }
    let(:output) { repo.join("github_output") }
    let(:summary) { repo.join("step_summary") }
    let(:gh_log) { fakebin.join("gh.log") }
    let(:runs) { fakebin.join("runs.json") }
    let!(:green) { head }

    after { FileUtils.rm_rf(fakebin) }

    let(:sleeps) { fakebin.join("sleeps.log") }

    before do
      fakebin.join("gh").write(<<~'SH')
        #!/bin/sh
        echo "$@" >> "$FAKE_GH_LOG"
        n=$(wc -l < "$FAKE_GH_LOG" | tr -d ' ')
        if [ -f "$FAKE_GH_RESPONSE.$n" ]; then cat "$FAKE_GH_RESPONSE.$n"; elif [ -f "$FAKE_GH_RESPONSE" ]; then cat "$FAKE_GH_RESPONSE"; fi
      SH
      fakebin.join("gh").chmod(0o755)
      fakebin.join("fake_sleep.rb").write(
        "module Kernel\n  def sleep(seconds) = File.write(ENV.fetch(\"FAKE_SLEEP_LOG\"), \"\#{seconds}\\n\", mode: \"a\")\nend\n"
      )
    end

    def head
      Open3.capture2(CleanGitEnv::HASH, "git", "-C", repo.to_s, "rev-parse", "HEAD").first.chomp
    end

    def ci_runs(*list, poll: nil)
      Pathname.new([ runs, poll ].compact.join(".")).write({ workflow_runs: list }.to_json)
    end

    def passed_push(sha) = push_run(sha, "completed", "success")

    def push_run(sha, status, conclusion = nil)
      { id: 7, head_sha: sha, event: "push", status:, conclusion:, html_url: "https://example.test/runs/7" }
    end

    def slept = sleeps.exist? ? sleeps.read.lines.sum(&:to_i) : 0

    def green_skip(env = {})
      test_plan("--green-skip", "--github-output", env: {
        "PATH" => "#{fakebin}:#{ENV.fetch("PATH")}", "GITHUB_REPOSITORY" => "example/app", "FAKE_GH_LOG" => gh_log.to_s,
        "FAKE_GH_RESPONSE" => runs.to_s, "GITHUB_OUTPUT" => output.to_s, "GITHUB_STEP_SUMMARY" => summary.to_s,
        "RUBYOPT" => "#{ENV["RUBYOPT"]} -r#{fakebin.join("fake_sleep.rb")}", "FAKE_SLEEP_LOG" => sleeps.to_s
      }.merge(env))
    end

    it "skips the tests when the commit differs from a parent CI passed on only in the changelog" do
      commit_file("CHANGELOG.md", "# Changelog\n")
      commit_file("changelog.d/fix-x.md", "- Fixed x.\n")
      scratch_git(repo, "rm", "-q", "changelog.d/fix-x.md")
      commit_file("CHANGELOG.md", "# Changelog\n\n- Fixed x.\n")
      scratch_git(repo, "checkout", "-q", "-b", "release", green)
      scratch_git(repo, "merge", "-q", "--no-ff", "-m", "merge", "work")
      ci_runs(passed_push(green))

      out, status = green_skip

      expect(status.exitstatus).to eq(0)
      expect(output.read.lines(chomp: true)).to eq([ "full=false", "skip=true" ])
      expect(out).to include(green, "https://example.test/runs/7")
      expect(summary.read).to include(green)
      expect(gh_log.read).to include("repos/example/app/actions/workflows/ci.yml/runs?head_sha=#{green}&event=push")
      expect(gh_log.read).not_to include("status=")
    end

    it "skips a merge whose tree is identical to its green second parent, though its first parent differs in code" do
      scratch_git(repo, "checkout", "-q", "main")
      scratch_git(repo, "merge", "-q", "--no-ff", "-m", "merge", "next")
      ci_runs(passed_push(green))

      _out, status = green_skip

      expect(status.exitstatus).to eq(0)
      expect(output.read).to eq("full=false\nskip=true\n")
    end

    it "runs the tests when the change reaches past the changelog, without asking GitHub" do
      commit_file("CHANGELOG.md", "# Changelog\n")
      commit_file("app/models/y.rb", "class Y\nend\n")
      ci_runs(passed_push(green))

      out, _status = green_skip

      expect(output.read).to eq("skip=false\n")
      expect(out).to include("run the tests")
      expect(gh_log).not_to exist
    end

    it "does not count a deleted CHANGELOG.md as a changelog entry, since a spec requires the file" do
      commit_file("CHANGELOG.md", "# Changelog\n")
      ci_runs(passed_push(head))
      scratch_git(repo, "rm", "-q", "CHANGELOG.md")
      scratch_git(repo, "commit", "-qm", "drop changelog")

      _out, _status = green_skip

      expect(output.read).to eq("skip=false\n")
    end

    it "does not count changelog.d's README as a changelog entry, since a spec reads it" do
      commit_file("changelog.d/README.md", "# Fragments\n")
      ci_runs(passed_push(green))

      _out, _status = green_skip

      expect(output.read).to eq("skip=false\n")
    end

    {
      "no run" => [],
      "a run that failed" => [ { head_sha: :green, event: "push", status: "completed", conclusion: "failure" } ],
      "a pull request's run, which tested a merge commit, not this one" => [ { head_sha: :green, event: "pull_request", conclusion: "success" } ],
      "another commit's run" => [ { head_sha: "0" * 40, event: "push", conclusion: "success" } ]
    }.each do |found, list|
      it "runs the tests when the lookup finds #{found}" do
        commit_file("CHANGELOG.md", "# Changelog\n")
        ci_runs(*list.map { |run| run.merge(head_sha: run[:head_sha] == :green ? green : run[:head_sha]) })

        out, status = green_skip

        expect(status.exitstatus).to eq(0)
        expect(output.read).to eq("skip=false\n")
        expect(out).to include("no passing CI push run")
      end
    end

    context "when the parent's push run has not finished" do
      before { commit_file("CHANGELOG.md", "# Changelog\n") }

      it "waits for it, then skips the tests once it passes" do
        ci_runs(push_run(green, "queued"), poll: 1)
        ci_runs(push_run(green, "in_progress"), poll: 2)
        ci_runs(passed_push(green), poll: 3)

        out, status = green_skip

        expect(status.exitstatus).to eq(0)
        expect(output.read).to eq("full=false\nskip=true\n")
        expect(sleeps.read.lines(chomp: true)).to eq(%w[20 20])
        expect(out).to include("CI passed on it (https://example.test/runs/7) after waiting 40s for that run")
      end

      it "waits for it, then runs the tests when it fails" do
        ci_runs(push_run(green, "in_progress"), poll: 1)
        ci_runs(push_run(green, "completed", "failure"), poll: 2)

        out, _status = green_skip

        expect(output.read).to eq("skip=false\n")
        expect(slept).to eq(20)
        expect(out).to include("no passing CI push run was found for it: its run concluded failure after waiting 20s")
      end

      it "gives up at the cap and runs the tests" do
        ci_runs(push_run(green, "in_progress"))

        out, _status = green_skip("GREEN_SKIP_WAIT_SECONDS" => "100")

        expect(output.read).to eq("skip=false\n")
        expect(slept).to eq(100)
        expect(out).to include("its run was still in_progress after waiting 100s")
      end

      it "spends one wait across both parents of a merge" do
        first = head
        scratch_git(repo, "checkout", "-q", "-b", "other", green)
        commit_file("changelog.d/fix-x.md", "- Fixed x.\n")
        second = head
        scratch_git(repo, "checkout", "-q", "work")
        scratch_git(repo, "merge", "-q", "--no-ff", "-m", "merge", "other")
        ci_runs(push_run(first, "in_progress"), push_run(second, "in_progress"))

        out, _status = green_skip("GREEN_SKIP_WAIT_SECONDS" => "100")

        expect(output.read).to eq("skip=false\n")
        expect(slept).to eq(100)
        expect(out).to include(first, second)
      end

      it "waits 8 minutes by default" do
        ci_runs(push_run(green, "queued"))

        _out, _status = green_skip

        expect(slept).to eq(480)
      end
    end

    it "gives a run that has not appeared a short grace, then runs the tests" do
      commit_file("CHANGELOG.md", "# Changelog\n")
      ci_runs

      out, _status = green_skip

      expect(output.read).to eq("skip=false\n")
      expect(slept).to eq(60)
      expect(out).to include("no passing CI push run was found for it: none appeared within 60s")
    end

    it "gives no grace to a parent on neither next nor main, since push CI never runs on it" do
      commit_file("CHANGELOG.md", "# Changelog\n")
      unpushed = head
      commit_file("changelog.d/fix-x.md", "- Fixed x.\n")
      ci_runs

      out, _status = green_skip

      expect(output.read).to eq("skip=false\n")
      expect(slept).to eq(0)
      expect(out).to include("#{unpushed} differs only in the changelog, but no passing CI push run was found for it: none")
    end

    it "waits for a run that appears during the grace" do
      commit_file("CHANGELOG.md", "# Changelog\n")
      ci_runs(poll: 1)
      ci_runs(passed_push(green), poll: 2)

      _out, _status = green_skip

      expect(output.read).to eq("full=false\nskip=true\n")
      expect(slept).to eq(20)
    end

    it "runs the tests when GitHub can't be asked" do
      commit_file("CHANGELOG.md", "# Changelog\n")

      out, status = green_skip

      expect(status.exitstatus).to eq(0)
      expect(output.read).to eq("skip=false\n")
      expect(out).to include("the CI lookup for #{green} failed")
    end
  end

  it "never hands rspec an empty list, which would run the whole suite" do
    scratch_git(repo, "rm", "-q", "spec/i18n_spec.rb")
    scratch_git(repo, "commit", "-qm", "drop spec")
    scratch_git(repo, "update-ref", "refs/remotes/origin/next", "HEAD")
    commit_file("config/locales/en.yml", "en:\n  hi: Hi\n")

    out, status = test_plan("--run")

    expect(status.exitstatus).to eq(0)
    expect(out).to eq("lanes: locale\ntest-plan: no specs selected\n")
  end
end
