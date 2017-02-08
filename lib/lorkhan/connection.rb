require 'net-http2'
require 'openssl'

module Lorkhan
  APNS_PRODUCTION_HOST  = 'api.push.apple.com'.freeze
  APNS_DEVELOPMENT_HOST = 'api.development.push.apple.com'.freeze

  class Connection
    attr_reader :host, :token

    def initialize(token:, production: true, timeout: 30)
      @host    = production ? APNS_PRODUCTION_HOST : APNS_DEVELOPMENT_HOST
      @timeout = timeout
      @token   = token
      @client  = NetHttp2::Client.new(url, connect_timeout: @connect_timeout)
    end

    def close
      @client.close
    end

    def join
      @client.join
    end

    def refresh_token
      @auth_token = nil
      close
    end

    def push(notification)
      request = Request.new(notification)
      request.validate!
      headers = request.headers
      headers['authorization'] = "bearer #{auth_token}"
      raw_response = @client.call(:post, request.path, body: request.body, headers: headers, timeout: 5)
      raise Errors::TimeoutError if raw_response.nil?
      response = Response.new(raw_response)
      handle_http_error(response) unless response.ok?
      response
    end

    private

    def auth_token
      @auth_token ||= token.encode
    end

    def url
      "https://#{host}:443"
    end

    def handle_http_error(response)
      if response.body
        if (reason = response.body['reason'])
          klass = Lorkhan::Errors::Apple::MAPPINGS[reason]
          raise klass, response if klass
        end
      end
      raise Errors::HTTPError, response
    end
  end
end
