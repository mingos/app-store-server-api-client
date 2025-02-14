# frozen_string_literal: true
#== run command
# bundle exec rspec spec/app_store_server_api_spec.rb
#
#== set environment variable
# You need to set values for the environment variables to pass the tests.
# Here is an example using bash.
# The values are just samples and will not work as is.
#
# ```bash
# export issuer_id="13b5ef32-1a08-35a2-e148-5b8c7c11a4d1"
# export key_id="3KB13592P3"
# export private_key=$'-----BEGIN PRIVATE KEY-----\n......\n-----END PRIVATE KEY-----'
# export bundle_id='com.myapp.app'
# export transaction_id='2000000151031281'
# ```
RSpec.describe AppStoreServerApi do

  # sandbox client
  let(:client) {
    AppStoreServerApi::Client.new(
      private_key: ENV['private_key'],
      key_id: ENV['key_id'],
      issuer_id: ENV['issuer_id'],
      bundle_id: ENV['bundle_id'],
      environment: :sandbox
    )
  }

  # no exist transaction_id
  let(:no_exist_transaction_id) {'2000000151031281'}

  # production client
  let(:production_client) {
    AppStoreServerApi::Client.new(
      private_key: ENV['private_key'],
      key_id: ENV['key_id'],
      issuer_id: ENV['issuer_id'],
      bundle_id: ENV['bundle_id'],
      environment: :production
    )
  }

  describe 'Client' do

    describe '#generate_bearer_token' do

      it 'generate a bearer token' do
        issued_at = Time.now
        expired_in = 600 # 10 minutes
        token = client.generate_bearer_token(issued_at: issued_at, expired_in: expired_in)

        # decode token
        payload, headers = JWT.decode(token, nil, false)
        expect(payload).to match({
          'iss' => client.issuer_id,
          'iat' => issued_at.to_i,
          'exp' => (issued_at + expired_in).to_i,
          'aud' => 'appstoreconnect-v1',
          'bid' => client.bundle_id
        })

        expect(headers).to match({
          'alg' => 'ES256',
          'kid' => client.key_id,
          'typ' => 'JWT'
        })
      end

    end

    describe '#get_transaction_info', :get_transaction_info do

      let(:transaction_id) {ENV['transaction_id']}

      context 'when request exist transaction_id' do

        it 'get transaction info' do
          transaction_info = client.get_transaction_info(transaction_id)

          expect(transaction_info).to be_a Hash
          expect(transaction_info['transactionId']).to eq transaction_id
          expect(transaction_info['bundleId']).to eq client.bundle_id
          expect(transaction_info['environment']).to eq 'Sandbox'
          expect(transaction_info['inAppOwnershipType']).to eq 'PURCHASED'
          expect(transaction_info['transactionReason']).to eq 'PURCHASE'
        end

      end

      # When querying the sandbox transaction ID in production,
      # an unauthorized error occurs.
      context 'request to production with sandbox transaction id' do

        it 'get unauthorized error' do
          expect {
            production_client.get_transaction_info(transaction_id)
          }.to raise_error(AppStoreServerApi::Error::UnauthorizedError)
        end

      end

      context 'when request no exist transaction_id' do

        it 'get not found error' do
          expect {
            client.get_transaction_info(no_exist_transaction_id)
          }.to raise_error(AppStoreServerApi::Error::TransactionIdNotFoundError) do |error|
            expect(error.code).to eq 4040010
            expect(error.message).to eq 'Transaction id not found.'
          end
        end

      end

      context 'when request invalid transaction_id' do

        it 'get not invalid transaction_id error' do
          expect {
            client.get_transaction_info('invalid_transaction_id')
          }.to raise_error(AppStoreServerApi::Error::InvalidTransactionIdError) do |error|
            expect(error.code).to eq 4000006
            expect(error.message).to eq 'Invalid transaction id.'
          end
        end

      end

    end

    describe '#request_test_notification' do

      it 'request a test notification' do
        # response example:
        # {"testNotificationToken"=>"9f90efb9-2f75-4dbe-990c-5d1fc89f4546_1739179413123"}
        result = client.request_test_notification
        expect(result).to be_a Hash
        expect(result.has_key?('testNotificationToken')).to be true
      end

    end

    describe '#get_test_notification_status' do

      context 'when request with invalid test notification token' do

        it 'get invalid request error' do
          expect {
            client.get_test_notification_status('invalid_test_notification_token')
          }.to raise_error(AppStoreServerApi::Error::InvalidTestNotificationTokenError) do |error|
            expect(error.code).to eq 4000020
            expect(error.message).to eq 'Invalid request. The test notification token is invalid.'
          end
        end

      end

      context 'when request no exist test_notification_token' do

        let(:test_notification_token) {'f199bc0e-1b24-40ce-abbf-4bbd34ebbf50_1739506488137'}

        it 'get expired or not yet available error' do
          expect {
            client.get_test_notification_status(test_notification_token)
          }.to raise_error(AppStoreServerApi::Error::TestNotificationNotFoundError) do |error|
            expect(error.code).to eq 4040008
            expect(error.message).to eq 'The test notification token is expired or the notification and status are not yet available.'
          end
        end

      end

      context 'when request with valid test notification token' do

        it 'get test notification status' do
          # request a test notification
          test_notification_token = client.request_test_notification['testNotificationToken']

          # wait for the test notification to be sent
          # because the test notification is not sent immediately
          sleep 2

          # get test notification status
          # response example:
          # {
          #   "signedPayload"=> "eyJhbGciOiJFUzI1NiIsIng1YyI6...",
          #   "firstSendAttemptResult"=>"SUCCESS",
          #   "sendAttempts"=>[{"attemptDate"=>1739179888814, "sendAttemptResult"=>"SUCCESS"}]
          # }
          result = client.get_test_notification_status(test_notification_token)

          expect(result.has_key?('signedPayload')).to be true
          expect(result.has_key?('sendAttempts')).to be true

          payload = AppStoreServerApi::Utils::Decoder.decode_jws!(result['signedPayload'])

          token_uuid = test_notification_token.split('_', 2).first

          # payload example:
          # {
          #   "notificationType"=>"TEST",
          #   "notificationUUID"=>"3838df56-31ab-4e2e-9535-e6e9377c4c77",
          #   "data"=>{"bundleId"=>"com.myapp.app", "environment"=>"Sandbox"},
          #   "version"=>"2.0",
          #   "signedDate"=>1739180480080
          # }
          expect(payload['notificationType']).to eq 'TEST'
          expect(payload['notificationUUID']).to eq token_uuid
          expect(payload['data']['bundleId']).to eq client.bundle_id
          expect(payload['data']['environment']).to eq 'Sandbox'
          expect(payload['version']).to eq '2.0'
          expect(payload['signedDate']).to be_a Integer # Unixtimemillis
        end
      end

    end

    describe '#get_transaction_history', :get_transaction_history do

      context 'when request exist transaction_id, with {sort: DESCENDING}' do

        let(:transaction_id) {ENV['transaction_id']}
        let(:params) {{sort: 'DESCENDING'}}

        it 'get a customer\'s in-app purchase transaction histories' do
          res = client.get_transaction_history(transaction_id, params: params)
          expect(res).to be_a Hash

          expect(res['bundleId']).to eq client.bundle_id
          expect(res['environment']).to eq 'Sandbox'
          expect(res['hasMore']).to be false
          expect(res['signedTransactions'].size).to be > 0

          transactions = AppStoreServerApi::Utils::Decoder.decode_transactions(signed_transactions: res["signedTransactions"])
          transactions.each do |transaction|
            expect(transaction).to be_a Hash
            expect(transaction.has_key?('transactionId')).to be true
            expect(transaction.has_key?('productId')).to be true
            expect(transaction['bundleId']).to eq client.bundle_id
          end
        end

      end

      context 'when no exist transaction_id' do

        it 'get not found error' do
          expect {
            client.get_transaction_history(no_exist_transaction_id)
          }.to raise_error(AppStoreServerApi::Error::TransactionIdNotFoundError) do |error|
            expect(error.code).to eq 4040010
            expect(error.message).to eq 'Transaction id not found.'
          end

        end

      end

    end

  end

end
