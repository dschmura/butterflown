# frozen_string_literal: true

require "rails_helper"
require "tmpdir"
require "open3"
require "erb"

load Rails.root.join("bin/deploy-setup")

RSpec.describe DeploySetup do
  let(:output) { StringIO.new }

  around do |example|
    Dir.mktmpdir do |dir|
      @tmp = Pathname.new(dir)
      @root = @tmp.join("root")
      %w[root/bin root/config stubs].each { |name| @tmp.join(name).mkpath }
      @root.join("config/deploy.yml").write(Rails.root.join("config/deploy.yml").read)
      stub("ssh", 'echo "ssh $*" >> LOG; echo x86_64')
      stub("fnox", 'echo "fnox $* <$(cat)>" >> LOG')
      stub("gh", "echo PRIVATE")
      stub_rails(exit_code: 0)
      example.run
    end
  end

  def deploy_yml = @root.join("config/deploy.yml").read
  def calls = @tmp.join("stub_calls.log").exist? ? @tmp.join("stub_calls.log").read : ""

  def stub(name, body)
    @tmp.join("stubs", name).write("#!/bin/sh\n#{body.gsub('LOG', @tmp.join('stub_calls.log').to_s)}\n")
    @tmp.join("stubs", name).chmod(0o755)
  end

  def unstub(name) = @tmp.join("stubs", name).delete

  def stub_rails(exit_code:)
    @root.join("bin/rails").write("#!/bin/sh\necho \"rails $*\" >> #{@tmp.join('stub_calls.log')}\nexit #{exit_code}\n")
    @root.join("bin/rails").chmod(0o755)
  end

  def run_setup(*answers)
    env = { "PATH" => "#{@tmp.join('stubs')}:/usr/bin:/bin" }
    described_class.new(root: @root.to_s, env:, input: StringIO.new(answers.map { "#{it}\n" }.join), output:).run
  end

  def deploy(kamal_host: nil)
    previous = ENV.fetch("KAMAL_HOST", nil)
    ENV["KAMAL_HOST"] = kamal_host
    YAML.safe_load(ERB.new(deploy_yml).result)
  ensure
    ENV["KAMAL_HOST"] = previous
  end

  it "writes the server, arch, proxy and domain, and the file still parses" do
    expect(run_setup("203.0.113.10", "", "", "", "app.example.com")).to eq(0)

    expect(deploy.dig("servers", "web", "hosts")).to eq([ "203.0.113.10" ])
    expect(deploy.dig("builder", "arch")).to eq("amd64")
    expect(deploy["proxy"]).to eq("ssl" => true, "host" => "app.example.com")
    expect(deploy.dig("env", "clear", "RAILS_HOST")).to eq("app.example.com")
    expect(deploy).not_to have_key("ssh")
    expect(calls).to include(" root@203.0.113.10 uname -m")
  end

  it "asks its questions in order, with each default in brackets" do
    run_setup("203.0.113.10", "", "", "", "app.example.com")

    expect(output.string.lines.filter_map { it[/\A[A-Z][^?\n]*\?(?= )/] }).to eq([
      "Server address?",
      "Keep the server address out of the repository (in fnox)?",
      "SSH user?",
      "Does something in front of the server handle HTTPS (another web server or a tunnel)?",
      "Domain?"
    ])
  end

  it "runs bin/rails deploy:check last and exits with its status" do
    stub_rails(exit_code: 1)

    expect(run_setup("203.0.113.10", "", "", "", "app.example.com")).to eq(1)
    expect(calls.lines.last).to eq("rails deploy:check\n")
  end

  describe "keeping the server out of the repository" do
    it "defaults to yes on a public repository and stores the address with fnox" do
      stub("gh", "echo PUBLIC")
      @root.join("fnox.toml").write("")

      run_setup("203.0.113.10", "", "", "", "app.example.com")

      expect(output.string).to include("(in fnox)? (Y/n)")
      expect(calls).to include("fnox set KAMAL_HOST --provider age-production <203.0.113.10>")
      expect(deploy_yml).to include(%(      - <%= ENV.fetch("KAMAL_HOST") { `fnox get KAMAL_HOST 2>/dev/null`[/\\S+/] || "deploy-host.invalid" } %>\n))
      expect(deploy_yml).not_to include("203.0.113.10")
      expect(deploy(kamal_host: "203.0.113.10").dig("servers", "web", "hosts")).to eq([ "203.0.113.10" ])
    end

    it "defaults to no on a private repository" do
      run_setup("203.0.113.10", "", "", "", "app.example.com")

      expect(output.string).to include("(in fnox)? (y/N)")
      expect(calls).not_to include("fnox set")
    end

    it "defaults to yes when gh can't say" do
      unstub("gh")

      run_setup("203.0.113.10", "n", "", "", "app.example.com")

      expect(output.string).to include("(in fnox)? (Y/n)")
    end

    it "stops before writing anything when fnox isn't there" do
      unstub("fnox")
      before = deploy_yml

      expect(run_setup("203.0.113.10", "y", "", "", "app.example.com")).to eq(1)
      expect(output.string).to include("Run bin/fnox-setup first")
      expect(deploy_yml).to eq(before)
      expect(calls).not_to include("deploy:check")
    end

    it "stops before writing anything when fnox can't store it" do
      stub("fnox", "exit 1")
      before = deploy_yml

      expect(run_setup("203.0.113.10", "y", "", "", "app.example.com")).to eq(1)
      expect(output.string).to include("bin/fnox-setup")
      expect(deploy_yml).to eq(before)
    end
  end

  describe "arch" do
    it "reads arm64 from an aarch64 server" do
      stub("ssh", "echo aarch64")

      run_setup("203.0.113.10", "", "", "", "app.example.com")

      expect(deploy.dig("builder", "arch")).to eq("arm64")
    end

    it "asks, defaulting to the current arch, when ssh can't reach the server" do
      stub("ssh", "exit 255")

      run_setup("203.0.113.10", "", "", "arm64", "", "app.example.com")

      expect(output.string).to include("Server arch, amd64 or arm64? [amd64]")
      expect(deploy.dig("builder", "arch")).to eq("arm64")
    end
  end

  it "uncomments ssh: with the user when it isn't root, and connects as that user" do
    run_setup("203.0.113.10", "", "deploy", "", "app.example.com")

    expect(deploy["ssh"]).to eq("user" => "deploy")
    expect(calls).to include(" deploy@203.0.113.10 uname -m")
  end

  it "runs kamal-proxy without SSL on the ports given when something in front handles HTTPS" do
    run_setup("203.0.113.10", "", "", "y", "", "9443", "app.example.com")

    expect(output.string).to include("HTTP port kamal-proxy listens on? [8080]")
    expect(deploy["proxy"]).to eq("ssl" => false, "host" => "app.example.com",
                                  "run" => { "http_port" => 8080, "https_port" => 9443 })
  end

  it "offers RAILS_HOST as the domain when it is already set" do
    @root.join("config/deploy.yml").write(deploy_yml.sub("    # RAILS_HOST: app.yourdomain.com", "    RAILS_HOST: shop.example.com #"))

    run_setup("203.0.113.10", "", "", "", "")

    expect(output.string).to include("Domain? [shop.example.com]")
    expect(deploy["proxy"]).to eq("ssl" => true, "host" => "shop.example.com")
  end

  describe "the shared preset" do
    it "asks for the owner's email and turns off creating more workspaces" do
      @root.join(".fork.yml").write("preset: shared\nname: acme\n")

      run_setup("203.0.113.10", "", "", "", "app.example.com", "owner@example.com")

      expect(deploy.dig("env", "clear")).to include("TENANCY_OWNER_EMAIL" => "owner@example.com",
                                                    "TENANCY_WORKSPACE_CREATION" => "disabled")
    end

    it "asks nothing about owners on the personal preset" do
      @root.join(".fork.yml").write("preset: personal\nname: acme\n")

      run_setup("203.0.113.10", "", "", "", "app.example.com")

      expect(output.string).not_to include("Owner")
      expect(deploy.dig("env", "clear")).not_to have_key("TENANCY_OWNER_EMAIL")
    end
  end

  it "offers what it wrote as the defaults the next time, and rewrites in place" do
    @root.join(".fork.yml").write("preset: shared\nname: acme\n")
    run_setup("203.0.113.10", "", "deploy", "y", "8081", "8444", "app.example.com", "owner@example.com")
    first = deploy_yml
    output.truncate(0)

    run_setup("", "", "", "", "", "", "", "")

    expect(output.string).to include("Server address? [203.0.113.10]", "SSH user? [deploy]", "(another web server or a tunnel)? (Y/n)",
                                     "[8081]", "[8444]", "Domain? [app.example.com]", "[owner@example.com]")
    expect(deploy_yml).to eq(first)
  end

  it "names what it couldn't change, and where to set it by hand, rather than guessing" do
    @root.join("config/deploy.yml").write(deploy_yml.sub(/^# proxy:\n#   ssl: true\n#   host: app.example.com\n/, ""))

    expect(run_setup("203.0.113.10", "", "", "", "app.example.com")).to eq(0)

    expect(output.string).to include("Couldn't find proxy: in config/deploy.yml", "set it by hand")
    expect(deploy.dig("servers", "web", "hosts")).to eq([ "203.0.113.10" ])
  end

  it "prints its usage for --help and changes nothing" do
    @root.join("bin/deploy-setup").write(Rails.root.join("bin/deploy-setup").read)
    @root.join("bin/deploy-setup").chmod(0o755)
    @root.join("lib").mkpath
    @root.join("lib/fork_config.rb").write(Rails.root.join("lib/fork_config.rb").read)
    before = deploy_yml

    printed, = Open3.capture2e(@root.join("bin/deploy-setup").to_s, "--help", chdir: @root.to_s)

    expect(printed).to include("Usage: bin/deploy-setup")
    expect(deploy_yml).to eq(before)
    expect(calls).to be_empty
  end
end
