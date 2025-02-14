# frozen_string_literal: true
module AppStoreServerApi

  class Error < StandardError
    attr_reader :code, :response

    # initialize error
    # @param [Integer] code error code
    # @param [String] message error message
    # @param [Faraday::Response] response error response
    def initialize(code:, message:, response:)
      super(message)
      @code = code
      @response = response
    end

    def to_h
      {
        code: code,
        message: message,
        response: response
      }
    end

    def inspect
      "#<#{self.class.name}: #{to_h.to_json}>"
    end

    # The JSON Web Token (JWT) in the authorization header is invalid.
    # For more information, see Generating JSON Web Tokens for API requests.
    # @see https://developer.apple.com/documentation/appstoreserverapi/generating-json-web-tokens-for-api-requests
    # other:
    #  - wrong environment (sandbox/production)
    class UnauthorizedError < Error
      def initialize(code: 4010000, message: 'unauthorized error', response:)
        super(code: code, message: message, response: response)
      end
    end

    class ServerError < Error
      def initialize(code: 5000000, message: 'Internal Server Error', response:)
        super(code: code, message: message, response: response)
      end
    end

    # error response body is invalid
    # must have errorCode and errorMessage.
    # valid example response body:
    #   {
    #     "errorCode": 4000006,
    #     "errorMessage": "Invalid transaction id."
    #   }
    class InvalidResponseError < Error
      def initialize(code: 5000002, message: 'response body is invalid', response:)
        super(code: code, message: message, response: response)
      end
    end

    class TransactionIdNotFoundError < Error; end

    class InvalidTransactionIdError < Error; end

    class RateLimitExceededError < Error; end

    class ServerNotificationURLNotFoundError < Error; end

    class InvalidTestNotificationTokenError < Error; end

    class TestNotificationNotFoundError < Error; end

    # map error code to error class
    ERROR_CODE_MAP = {
      4040010 => Error::TransactionIdNotFoundError,
      4000020 => Error::InvalidTestNotificationTokenError,
      4000006 => Error::InvalidTransactionIdError,
      4290000 => Error::RateLimitExceededError,
      4040007 => Error::ServerNotificationURLNotFoundError,
      4040008 => Error::TestNotificationNotFoundError,
    }.freeze

    # raise error from response
    # @param [Faraday::Response] response error response
    def self.handle_error(response)
      case response.status
      when 401
        # Unauthorized error
        # reasons:
        # - JWT in the authorization header is invalid.
        raise Error::UnauthorizedError.new(response: response)
      when 500
        raise Error::ServerError.new(response: response)
      else
        data = JSON.parse(response.body)

        # error object must be {errorCode: Integer, errorMessage: String}
        unless data.has_key?('errorCode') && data.has_key?('errorMessage')
          raise Error::InvalidResponseError.new(message: 'response body is invalid', response: response)
        end

        error_code = data['errorCode']
        error_class = ERROR_CODE_MAP[error_code] || Error
        raise error_class.new(code: error_code, message: data['errorMessage'], response: response)
      end
    end

  end

end