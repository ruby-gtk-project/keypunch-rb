# frozen_string_literal: true

require "json"
require "securerandom"
require "socket"

require_relative "typing_test_utils"

# DiscordRpc reports what the user is doing to a running Discord client, so it
# can show up as the app's rich presence.
#
# Ported from upstream's src/discord_rpc.rs. Upstream uses the
# `discord-presence` crate, which spawns a worker thread, reconnects on its
# own, and keeps the last activity around to resend once a connection comes
# up. This port keeps the same shape — a worker thread fed from a queue, the
# last activity stored and resent on connect — and speaks the Discord IPC
# protocol over the local socket directly, because there is no Ruby equivalent
# of the crate.
#
# The protocol is: connect to $XDG_RUNTIME_DIR/discord-ipc-N, send an opcode-0
# handshake frame carrying the client id, then opcode-1 frames with a
# SET_ACTIVITY command. Every frame is a little-endian opcode, a little-endian
# payload length, and the JSON payload.
#
# Discord not running is the normal case, not an error: nothing is reported,
# and a later connection attempt picks the stored activity up.
#
class DiscordRpc
  CLIENT_ID = "1320106636743802923"

  OP_HANDSHAKE = 0
  OP_FRAME = 1

  # How long to wait before looking for a Discord socket again.
  RECONNECT_INTERVAL = 15

  # The small image of the presence, by words per minute.
  WPM_IMAGES = [
    [10.0, "0-wpm"],
    [20.0, "10-wpm"],
    [30.0, "20-wpm"],
    [40.0, "30-wpm"],
    [50.0, "40-wpm"],
    [60.0, "50-wpm"],
    [70.0, "60-wpm"],
    [80.0, "70-wpm"],
    [90.0, "80-wpm"],
    [100.0, "90-wpm"],
    [110.0, "100-wpm"],
    [120.0, "110-wpm"],
    [130.0, "120-wpm"],
    [140.0, "130-wpm"],
    [150.0, "140-wpm"],
    [160.0, "150-wpm"],
    [170.0, "160-wpm"],
    [180.0, "170-wpm"],
    [190.0, "180-wpm"],
    [200.0, "190-wpm"],
  ].freeze

  FASTEST_IMAGE = "200-wpm"

  def self.wpm_image(wpm)
    WPM_IMAGES.find { |threshold, _| wpm < threshold }&.last || FASTEST_IMAGE
  end

  def initialize
    @queue = Queue.new
    @start_time = (Time.now.to_f * 1000).floor
    @worker = Thread.new { run }
    @worker.abort_on_exception = false
  end

  # Upstream's `RpcWrapper::set_activity`.
  def set_activity(config, state)
    @queue.push([:activity, details_string(config), TypingTestUtils::PresenceState.english_string(state)])
  end

  # Upstream's `RpcWrapper::set_stats`.
  def set_stats(wpm, accuracy)
    @queue.push([:stats, wpm, accuracy])
  end

  def shutdown
    @queue.push([:stop])
    @worker.join(1)
  end

  private

    def run
      details = nil
      state = nil
      stats = nil
      running = true

      while running
        message = @queue.pop

        case message.first
        when :stop
          running = false
        when :activity
          _, details, state = message
        when :stats
          _, wpm, accuracy = message
          stats = [wpm, accuracy]
        end

        if running
          send_activity(activity_payload(details, state, stats))
        end
      end

      close
    end

    def details_string(config)
      if config.finite?
        "Custom text"
      else
        "#{config.difficulty}, #{TypingTestUtils::TestDuration.english_string(config.duration)}"
      end
    end

    def activity_payload(details, state, stats)
      {
        state:      state,
        details:    details,
        timestamps: { start: @start_time },
        assets:     assets(stats),
      }.compact
    end

    def assets(stats)
      if stats
        wpm, accuracy = stats
        {
          large_image: "main",
          large_text:  "Keypunch",
          small_image: self.class.wpm_image(wpm),
          small_text:  format("%<wpm>.0f WPM, %<accuracy>.0f%% accuracy", wpm: wpm.floor, accuracy: (accuracy * 100).floor),
        }
      else
        {
          large_image: "main",
          large_text:  "Keypunch",
        }
      end
    end

    def send_activity(activity)
      if socket
        write_frame(
          OP_FRAME,
          {
            cmd:   "SET_ACTIVITY",
            args:  { pid: Process.pid, activity: activity },
            nonce: SecureRandom.uuid,
          },
        )
      end
    end

    # The connected socket, or nil when Discord is not reachable. A failed
    # attempt is not retried until RECONNECT_INTERVAL seconds have passed, so a
    # keystroke-driven activity update cannot turn into a connect storm.
    def socket
      if @socket.nil? && due_for_reconnect?
        @last_attempt = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        @socket = connect
      end

      @socket
    end

    def due_for_reconnect?
      @last_attempt.nil? ||
        Process.clock_gettime(Process::CLOCK_MONOTONIC) - @last_attempt >= RECONNECT_INTERVAL
    end

    def connect
      candidate_paths.lazy.filter_map { |path| handshake(path) }.first
    end

    def candidate_paths
      base = ENV["XDG_RUNTIME_DIR"] || ENV["TMPDIR"] || "/tmp"
      (0..9).map { |index| File.join(base, "discord-ipc-#{index}") }
    end

    def handshake(path)
      begin
        @socket = UNIXSocket.new(path)
        write_frame(OP_HANDSHAKE, { v: 1, client_id: CLIENT_ID })
        @socket
      rescue SystemCallError, IOError
        close
        nil
      end
    end

    def write_frame(opcode, payload)
      begin
        body = JSON.generate(payload)
        @socket.write([opcode, body.bytesize].pack("l<l<") + body)
      rescue SystemCallError, IOError
        close
      end
    end

    def close
      begin
        @socket&.close
      rescue SystemCallError, IOError
        nil
      end

      @socket = nil
    end
end
