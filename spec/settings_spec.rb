# frozen_string_literal: true

require "tmpdir"
require_relative "../lib/settings"

RSpec.describe Settings do
  around do |example|
    Dir.mktmpdir("keypunch-settings-spec") do |dir|
      @tmp_path = File.join(dir, "settings.json")
      example.run
    end
  end

  def build = described_class.new(path: @tmp_path)

  it "starts out with the documented defaults when no file exists yet" do
    settings = build
    expect(settings["window-width"]).to eq(900)
    expect(settings["window-height"]).to eq(450)
    expect(settings["window-maximized"]).to eq(false)
    expect(settings["session-type"]).to eq("Simple")
    expect(settings["session-duration"]).to eq("Sec30")
    expect(settings["recent-languages"]).to eq([])
    expect(settings["personal-best"]).to eq([])
  end

  it "persists a written value to disk and reloads it in a new instance" do
    build["session-type"] = "Advanced"

    reloaded = build
    expect(reloaded["session-type"]).to eq("Advanced")
  end

  it "notifies a listener registered with connect_changed for the key that changed" do
    settings = build
    seen = []
    settings.connect_changed("custom-text") { seen << settings["custom-text"] }

    settings["custom-text"] = "hello world"

    expect(seen).to eq(["hello world"])
  end

  it "does not notify a listener registered for a different key" do
    settings = build
    seen = []
    settings.connect_changed("session-type") { seen << :called }

    settings["custom-text"] = "hello world"

    expect(seen).to be_empty
  end

  it "falls back to the defaults when the settings file holds invalid JSON" do
    File.write(@tmp_path, "{ not json")

    settings = build
    expect(settings["window-width"]).to eq(900)
  end

  it "falls back to the defaults when the settings file holds a JSON value that is not an object" do
    File.write(@tmp_path, "[1, 2, 3]")

    settings = build
    expect(settings["session-type"]).to eq("Simple")
  end

  it "ignores unknown keys from a newer version of the file instead of crashing" do
    File.write(@tmp_path, JSON.generate("session-type" => "Advanced", "a-key-from-the-future" => true))

    settings = build
    expect(settings["session-type"]).to eq("Advanced")
  end

  it "reports its own location" do
    settings = build
    expect(settings.location).to eq(@tmp_path)
  end
end
