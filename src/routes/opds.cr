struct OPDSRouter
  def initialize
    get "/opds" do |env|
      titles = Library.default.titles
      render_xml "src/views/opds/index.xml.ecr"
    end

    get "/opds/book/:title_id" do |env|
      begin
        title = Library.default.get_title(env.params.url["title_id"]).not_nil!
        render_xml "src/views/opds/title.xml.ecr"
      rescue e
        Logger.error e
        env.response.status_code = 404
      end
    end
  end
end
