
  # this is an "abstract" base class that
class Base < JsonApiClient::Resource
  # set the api base url in an abstract base class
  self.site = ENV["PEST_SERVER"]
  property :id,          type: :int
end
Base.connection do |connection|
  # set OAuth2 headers

  # log responses
  connection.use Faraday::Response::Logger

end
