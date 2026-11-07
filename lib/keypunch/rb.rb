# frozen_string_literal: true

require_relative "rb/version"

# Gem entrypoint, required by spec/spec_helper.rb (`require "keypunch/rb"`)
# and whatever else resolves the gem by its `keypunch-rb` name rather than by
# `keypunch`. The app itself boots through lib/keypunch.rb, which this does
# not need to pull in: a spec that wants the app's classes requires them
# directly, the same way exe/keypunch does.
module Keypunch
  module Rb
  end
end
