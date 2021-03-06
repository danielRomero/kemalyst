require "./spec_helper"

describe Kemalyst::Handler::Route do
  it "returns the method" do
    route = Kemalyst::Handler::Route.new("GET", "/", Kemalyst::Handler::Base.instance)
    route.method.should eq "GET"
  end

  it "returns the path" do
    route = Kemalyst::Handler::Route.new("GET", "/", Kemalyst::Handler::Base.instance)
    route.path.should eq "/"
  end
  
  it "returns the handler" do
    route = Kemalyst::Handler::Route.new("GET", "/", Kemalyst::Handler::Base.instance)
    route.handler.should eq Kemalyst::Handler::Base.instance
  end
end

describe Kemalyst::Handler::Router do
  it "set content_type to text/html" do
    request = HTTP::Request.new("GET", "/")
    io, context = create_context(request)
    
    router = Kemalyst::Handler::Router.new
    handler = Kemalyst::Handler::Block.new(->(c : HTTP::Server::Context) { "Hello World!" })
    router.add_route("GET", "/", handler)
    router.call(context)
    context.response.headers["content_type"].should eq "text/html"
  end

  it "set response body to Hello World!" do
    router = Kemalyst::Handler::Router.new
    handler = Kemalyst::Handler::Block.new(->(c : HTTP::Server::Context) { "Hello World!" })
    router.add_route("GET", "/", handler)

    request = HTTP::Request.new("GET", "/")
    io, context = create_context(request)
    router.call(context)
    context.response.close
    io.rewind
    client_response = HTTP::Client::Response.from_io(io, decompress: false)
    client_response.body.should eq "Hello World!"
  end

  it "builds handler callstack for routes" do
    router = Kemalyst::Handler::Router.new
    handler = Kemalyst::Handler::Block.new(->(c : HTTP::Server::Context) { "Hello World!" })
    
    router.add_route("GET", "/", 
     [Kemalyst::Handler::WebSocket.new(->(ws : HTTP::WebSocket){}), handler])
    request = HTTP::Request.new("GET", "/")
    io, context = create_context(request)
    router.call(context)
    context.response.close
    io.rewind
    client_response = HTTP::Client::Response.from_io(io, decompress: false)
    client_response.body.should eq "Hello World!"
  end
end


