# frozen_string_literal: true
require 'jwt'
require 'faraday'
require 'uri'
require 'json'
require 'openssl'

module AppStoreServerApi
  class Client
    attr_reader :environment, :issuer_id, :key_id, :private_key, :bundle_id

    PAYLOAD_AUD = 'appstoreconnect-v1'
    TOKEN_TYPE = 'JWT'
    ENCODE_ALGORITHM = 'ES256'
    ENVIRONMENTS = [:production, :sandbox].freeze
    API_BASE_URLS = {
      :production => 'https://api.storekit.itunes.apple.com',
      :sandbox => 'https://api.storekit-sandbox.itunes.apple.com'
    }.freeze

    # initialize client
    # @param private_key [String] p8 key
    # @param key_id [String] Your private key ID from App Store Connect (Ex: 2X9R4HXF34)
    # @param issuer_id [String] Your issuer ID from the Keys page in App Store Connect
    # @param bundle_id [String] Your app’s bundle ID (Ex: “com.example.testbundleid”)
    # @param environment [Symbol] :production or :sandbox
    def initialize(private_key:, key_id:, issuer_id:, bundle_id:, environment: :production)
      self.environment = environment.to_sym
      @issuer_id = issuer_id
      @key_id = key_id
      @private_key = private_key
      @bundle_id = bundle_id
      @http_client = Utils::HttpClient.new
    end

    # set environment
    # @param env [Symbol] :production or :sandbox
    # @raise [ArgumentError] if env is not :production or :sandbox
    def environment=(env)
      unless ENVIRONMENTS.include?(env)
        raise ArgumentError, 'environment must be :production or :sandbox'
      end

      @environment = env
    end

    # get information about a single transaction
    # @see https://developer.apple.com/documentation/appstoreserverapi/get-v1-transactions-_transactionid_
    # @param [String] transaction_id The identifier of a transaction
    # @return [Hash] transaction info
    def get_transaction_info(transaction_id)
      path = "/inApps/v1/transactions/#{transaction_id}"
      response = do_request(path)
      json = JSON.parse(response.body)
      payload, = Utils::Decoder.decode_jws!(json['signedTransactionInfo'])
      payload
    end

    # Request a Test Notification
    # @see https://developer.apple.com/documentation/appstoreserverapi/post-v1-notifications-test
    # @return [Hash] test notification token info
    def request_test_notification
      path = '/inApps/v1/notifications/test'
      response = do_request(path, method: :post, params: {}.to_json)
      JSON.parse(response.body)
    end

    # Get Test Notification Status
    # @see https://developer.apple.com/documentation/appstoreserverapi/get-v1-notifications-test-_testnotificationtoken_
    def get_test_notification_status(test_notification_token)
      path = "/inApps/v1/notifications/test/#{test_notification_token}"
      response = do_request(path)
      JSON.parse(response.body)
    end

    # Get Transaction History
    # @see https://developer.apple.com/documentation/appstoreserverapi/get-v2-history-_transactionid_
    # @param [String] transaction_id The identifier of a transaction
    # @param [Hash] params request params
    # @return [Hash] transaction history
    def get_transaction_history(transaction_id, params: {})
      path = "/inApps/v2/history/#{transaction_id}"
      response = do_request(path, params: params)
      JSON.parse(response.body)
    end

    # generate bearer token
    # @param issued_at [Time] issued at
    # @param expired_in [Integer] expired in seconds (max 3600)
    # @return [String] bearer token
    def generate_bearer_token(issued_at: Time.now, expired_in: 3600)
      # expirations longer than 60 minutes will be rejected
      if expired_in > 3600
        raise ArgumentError, 'expired_in must be less than or equal to 3600'
      end

      headers = {
        alg: ENCODE_ALGORITHM,
        kid: key_id,
        typ: TOKEN_TYPE,
      }

      payload = {
        iss: issuer_id,
        iat: issued_at.to_i,
        exp: (issued_at + expired_in).to_i,
        aud: PAYLOAD_AUD,
        bid: bundle_id
      }

      JWT.encode(payload, OpenSSL::PKey::EC.new(private_key), ENCODE_ALGORITHM, headers)
    end

    def api_base_url
      API_BASE_URLS[environment]
    end

    def base_request_headers(bearer_token)
      {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{bearer_token}"
      }
    end

    # send get request to App Store Server API
    # @param [String] path request path
    # @param [Symbol] method request method
    # @param [Hash,String,nil] params request params
    # @param [Hash] headers additional headers
    # @return [Faraday::Response] response
    #
    # @raise [Error::UnauthorizedError] if unauthorized error
    # @raise [Error::ServerError] if server error
    # @raise [Error] if other error
    def do_request(path, method: :get, params: {}, headers: {}, open_timeout: 10, read_timeout: 30)
      request_url = api_base_url + path
      bearer_token = generate_bearer_token
      request_headers = base_request_headers(bearer_token).merge(headers)

      response = @http_client.request_with_retry(
        url: request_url,
        method: method,
        params: params,
        headers: request_headers)

      if response.success?
        return response
      end

      Error.handle_error(response)
    end

  end

end