# frozen_string_literal: true
require 'faraday'
require 'retriable'

module AppStoreServerApi

  module Utils

    class HttpClient
      DEFAULT_OPEN_TIMEOUT = 10
      DEFAULT_READ_TIMEOUT = 30
      RETRY_ERRORS = [Faraday::TimeoutError, Faraday::ConnectionFailed, Faraday::ServerError]

      # initialize client
      # @param open_timeout [Integer] open timeout
      # @param read_timeout [Integer] read timeout
      def initialize(open_timeout: DEFAULT_OPEN_TIMEOUT, read_timeout: DEFAULT_READ_TIMEOUT)
        @open_timeout = open_timeout
        @read_timeout = read_timeout
      end

      def build_connection
        Faraday.new do |f|
          f.adapter :net_http do |http|
            http.open_timeout = @open_timeout
            http.read_timeout = @read_timeout
          end
        end
      end

      def connection
        @connection ||= build_connection
      end

      # send request
      # @param url [String] request url
      # @param method [Symbol] request method(:get, :post, :put, :patch, :delete)
      # @param params [Hash,String,nil] request params
      # @param headers [Hash] request headers
      # @return [Faraday::Response]
      def request(url:, method: :get, params: {}, headers: {})
        method = method.to_sym

        case method
        when :get, :delete
          connection.run_request(method, url, nil, headers) do |req|
            req.params.update(params) if params.is_a?(Hash)
          end
        when :post, :put, :patch
          connection.run_request(method, url, params, headers)
        else
          raise ArgumentError, "Unsupported HTTP method: #{method}"
        end
      end

      # send request with retry
      # @param url [String] request url
      # @param method [Symbol] request method
      # @param params [Hash,String,nil] request params
      # @param headers [Hash] request headers
      # @param retries [Integer] retry count
      # @param base_interval [Float] base interval
      # @param multiplier [Float] multiplier
      # @param max_interval [Float] max interval
      # @return [Faraday::Response]
      def request_with_retry(url:, method: :get, params: {}, headers: {}, retries: 3,
        base_interval: 0.5, multiplier: 1.0, max_interval: 30)

        Retriable.retriable tries: retries,
          base_interval: base_interval,
          max_interval: max_interval,
          multiplier: multiplier,
          on: RETRY_ERRORS do
          request(url: url, method: method, params: params, headers: headers)
        end
      end

    end

  end

end