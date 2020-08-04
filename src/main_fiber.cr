# On ARM, connecting to the SQLite DB from a spawned fiber would crash
#   https://github.com/crystal-lang/crystal-sqlite3/issues/30
# This is a temporary workaround that forces the relevant code to run in the
#   main fiber

class MainFiber
  @@channel = Channel(-> Nil).new
  @@done = Channel(Bool).new

  def self.start_and_block
    loop do
      if proc = @@channel.receive
        begin
          proc.call
        ensure
          @@done.send true
        end
      end
      Fiber.yield
    end
  end

  def self.run(&block : -> Nil)
    @@channel.send block
    until @@done.receive
      Fiber.yield
    end
  end
end
