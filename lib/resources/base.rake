require 'json_api_client'
  # this is an "abstract" base class that
class Base < JsonApiClient::Resource
  # set the api base url in an abstract base class
  self.site = ENV["PEST_SERVER"]
  property :id,          type: :int
end

Base.connection do |connection|
  # set OAuth2 headers

  # log responses
  connection.use Faraday::Request::BasicAuthentication, ENV["PEST_USERNAME"], ENV["PEST_PASSWORD"]
  #connection.use Faraday::Response::Logger
 
end
