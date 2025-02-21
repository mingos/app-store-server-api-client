# frozen_string_literal: true
require 'faraday'
require 'retriable'

module AppStoreServerApi

  module Utils

    # Retriable options
    # @see https://github.com/kamui/retriable
    class RetriableOptions

      # Number of attempts to make at running your code block (includes initial attempt).
      # @return [Integer] default: 3
      attr_reader :tries

      # The initial interval in seconds between tries.
      # @return [Float] default: 0.5
      attr_reader :base_interval

      # Each successive interval grows by this factor.
      # A multiplier of 1.5 means the next interval will be 1.5x the current interval.
      # @return [Float] default: 1.5
      attr_reader :multiplier

      # The maximum amount of total time in seconds that code is allowed to keep being retried.
      # @return [Float]
      attr_reader :max_elapsed_time

      # The maximum interval in seconds that any individual retry can reach.
      # @return [Float]
      attr_reader :max_interval

      def initialize(tries: 3, base_interval: 0.5, multiplier: 1.5, max_elapsed_time: 900, max_interval: 60)
        @tries = tries
        @base_interval =base_interval
        @multiplier = multiplier
        @max_elapsed_time = max_elapsed_time
        @max_interval = max_interval
      end

    end

    class HttpClient
      DEFAULT_OPEN_TIMEOUT = 10
      DEFAULT_READ_TIMEOUT = 30
      RETRY_ERRORS = [Faraday::TimeoutError, Faraday::ConnectionFailed, Faraday::ServerError]

      # initialize client
      # @param [Integer] open_timeout open timeout
      # @param [Integer] read_timeout read timeout
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
      # @param [String] url request url
      # @param [Symbol] method request method(:get, :post, :put, :patch, :delete)
      # @param [Hash,String,nil] params request params
      # @param [Hash] headers request headers
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
      # @param [String] url request url
      # @param [Symbol] method request method
      # @param [Hash,String,nil] params request params
      # @param [Hash] headers request headers
      # @param [RetriableOptions] retriable_options retriable options
      # @return [Faraday::Response]
      def request_with_retry(url:, method: :get, params: {}, headers: {}, retriable_options: RetriableOptions.new)
        Retriable.retriable tries: retriable_options.tries,
          base_interval: retriable_options.max_interval,
          max_interval: retriable_options.max_interval,
          multiplier: retriable_options.multiplier,
          max_elapsed_time: retriable_options.max_elapsed_time,
          on: RETRY_ERRORS do
          request(url: url, method: method, params: params, headers: headers)
        end
      end

    end

  end

end