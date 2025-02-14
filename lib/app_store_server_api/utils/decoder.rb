# frozen_string_literal: true
require 'openssl'
require 'jwt'

module AppStoreServerApi
  module Utils
    module Decoder
      module_function

      # Decode a signed JWT
      # @param [String] jws The signed JWT to decode
      # @return [Hash] The decoded payload
      def decode_jws!(jws)
        apple_cert_store = make_apple_cert_store

        payload, = JWT.decode(jws, nil, true, {algorithm: 'ES256'}) do |headers|
          # verify the certificate included in the header x5c
          cert_target, *cert_chain = headers['x5c'].map {|cert| OpenSSL::X509::Certificate.new(Base64.decode64(cert))}
          apple_cert_store.verify(cert_target, cert_chain)
          cert_target.public_key
        end

        payload
      end

      def decode_transaction(signed_transaction:)
        decode_jws! signed_transaction
      end

      def decode_transactions(signed_transactions:)
        signed_transactions.map do |signed_transaction|
          decode_transaction signed_transaction: signed_transaction
        end
      end

      def apple_root_certs
        Dir.glob(File.join(__dir__, 'certs', '*.cer')).map do |filename|
          OpenSSL::X509::Certificate.new File.read(filename)
        end
      end

      def make_apple_cert_store
        apple_cert_store = OpenSSL::X509::Store.new
        apple_root_certs.each do |cert|
          apple_cert_store.add_cert cert
        end

        apple_cert_store
      end

    end
  end
end
