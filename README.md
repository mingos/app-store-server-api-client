# App Store Server API Client

A Ruby client for
the [App Store Server API](https://developer.apple.com/documentation/appstoreserverapi).

## Support API Endpoints

* [Get Transaction Info](https://developer.apple.com/documentation/appstoreserverapi/get-v1-transactions-_transactionid_)
* [Request a Test Notification](https://developer.apple.com/documentation/appstoreserverapi/post-v1-notifications-test)
* [Get Test Notification Status](https://developer.apple.com/documentation/appstoreserverapi/get-v1-notifications-test-_testnotificationtoken_)
* [Get Transaction History](https://developer.apple.com/documentation/appstoreserverapi/get-v2-history-_transactionid_)

## Requirements

Ruby 3.3.0 or later.

## Installation

add this line to your application's Gemfile:

```Gemfile
gem 'app_store_server_api_client'
```

## Usage

### Prerequisites

To use this, please obtain an API Key.
https://developer.apple.com/documentation/appstoreserverapi/creating-api-keys-to-authorize-api-requests

### Configure

**In your Rails application, create a client configure**

```yaml
# my_app/config/app_store_server.yml
default: &default
  private_key: |
    -----BEGIN PRIVATE KEY-----
    ...
    -----END PRIVATE KEY-----
  key_id: Z1BT391B21
  issuer_id: ef02153z-1290-3519-875e-237a15237e3c
  bundle_id: com.myapp.app
  environment: sandbox

development:
  <<: *default

test:
  <<: *default

production:
  <<: *default
```

### load the configuration

```ruby
config = Rails.application.config_for(:app_store_server)
client = AppStoreServerApi::Client.new(**config)
```

## API

### Get Transaction Info

[Get Transaction Info](
https://developer.apple.com/documentation/appstoreserverapi/get-v1-transactions-_transactionid_)

Get information about a single transaction for your app.

```ruby
transaction_id = '2000000847061981'
client.get_transaction_info(transaction_id)
=>
  {
    "transactionId" => "2000000847061981",
    "originalTransactionId" => "2000000847061981",
    "bundleId" => "com.myapp.app",
    "productId" => "com.myapp.app.product",
    "type" => "Consumable",
    "purchaseDate" => 1738645560000,
    "originalPurchaseDate" => 1738645560000,
    "quantity" => 1,
    ...
  }
```

### Request a Test Notification

[Request a Test Notification](https://developer.apple.com/documentation/appstoreserverapi/post-v1-notifications-test)

Ask App Store Server Notifications to send a test notification to your server.

```ruby
result = client.request_test_notification
#=> {"testNotificationToken"=>"9f90efb9-2f75-4dbe-990c-5d1fc89f4546_1739179413123"}
```

### Get Test Notification Status

[Get Test Notification Status](https://developer.apple.com/documentation/appstoreserverapi/get-v1-notifications-test-_testnotificationtoken_)

Check the status of the test App Store server notification sent to your server.

```ruby
test_notification_token = client.request_test_notification['testNotificationToken']
result = client.get_test_notification_status(test_notification_token)
#=> {
#  "signedPayload"=> "eyJhbGciOiJFUzI1NiIsIng1YyI6...",
#  "firstSendAttemptResult"=>"SUCCESS",
#  "sendAttempts"=>[{"attemptDate"=>1739179888814, "sendAttemptResult"=>"SUCCESS"}]
#}

signed_payload = AppStoreServerApi::Utils::Decoder.decode_jws!(result['signedPayload'])
# => {
#   "notificationType"=>"TEST",
#   "notificationUUID"=>"3838df56-31ab-4e2e-9535-e6e9377c4c77",
#   "data"=>{"bundleId"=>"com.myapp.app", "environment"=>"Sandbox"},
#   "version"=>"2.0",
#   "signedDate"=>1739180480080
# }
```

### Get Transaction History

[Get Transaction History](https://developer.apple.com/documentation/appstoreserverapi/get-v2-history-_transactionid_)

Get a customer’s in-app purchase transaction history for your app.

```ruby
data = client.get_transaction_history(transaction_id,
  params: {
    sort: "DESCENDING"
  })

transactions = AppStoreServerApi::Utils::Decoder.decode_transactions(signed_transactions:
  data["signedTransactions"])
```

## Error Handling

```ruby

begin
  # response success
  transaction_info = client.get_transaction_info('invalid_transaction_id')
rescue AppStoreServerApi::Error => e
  # response failure
  # case of error: 
  # - http status 40x, 50x
  # - json parse error 
  puts e.code # => Integer
  puts e.message # => String
end
```

## License

The gem is available as open source under the terms of
the [MIT License](https://opensource.org/licenses/MIT).
