require "./server"
require "./context"

context = Context.new
server = Server.new context
server.start
