# frozen_string_literal: true

require "pty"
require "rbconfig"
require "timeout"

RSpec.describe "IRB terminal integration" do
  def read_until(reader, writer, output, expected)
    queries = 0
    Timeout.timeout(10) do
      until output.include?(expected)
        output << reader.readpartial(4096)
        count = output.scan("\e[6n").length
        if count > queries
          writer.write("\e[1;1R" * (count - queries))
          queries = count
        end
      end
    end
  end

  it "prints the image and leaves the result summary and prompt intact" do
    rc = Tempfile.new("inlay-irbrc")
    rc.write('require "inlay/irb"')
    rc.close
    ruby_path = RbConfig.ruby
    load_path = [File.expand_path("../lib", __dir__), File.expand_path("../../tessel/lib", __dir__), File.expand_path("../../termvas/lib", __dir__)].join(File::PATH_SEPARATOR)
    output = +""
    command = [ruby_path, "-I#{load_path}", "-e", "require 'irb'; IRB.start"]

    PTY.spawn({ "TERM" => "xterm-kitty", "TERMVAS_PROTOCOL" => "kitty", "IRBRC" => rc.path }, *command) do |reader, writer, pid|
      reader.winsize = [24, 80]
      read_until(reader, writer, output, "irb(main):001>")
      writer.puts('Tessel::Image.from_rgba(1, 1, [255, 0, 0, 255].pack("C*"))')
      read_until(reader, writer, output, "#<Tessel::Image 1x1>")
      writer.puts("exit")
      begin
        loop { output << reader.readpartial(4096) }
      rescue EOFError, Errno::EIO
        Process.wait(pid)
      end
    ensure
      begin
        Process.kill("TERM", pid) if pid && Process.waitpid(pid, Process::WNOHANG).nil?
      rescue Errno::ECHILD, Errno::ESRCH
      end
    end

    expect(output).to include("\e_G")
    expect(output).to include("#<Tessel::Image 1x1>")
    expect(output.scan(/irb\(main\):/).length).to be >= 2
  ensure
    rc&.unlink
  end
end
