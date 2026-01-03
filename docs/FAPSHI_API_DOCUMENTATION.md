https://docs.fapshi.com/en/api-reference/getting-started

API Overview
Getting Started with the API
Learn how to set up and use the Fapshi API, from creating API keys to making authenticated requests and understanding the API’s structure and capabilities.

The Fapshi API empowers you to build seamless and fully customized payment experiences within your website, app, or service. Whether you’re collecting payments or disbursing funds, the API gives you everything you need to go live quickly — in minutes, not days.
Have questions, feedback, or suggestions? Reach out via support@fapshi.com, or join the conversation in our Slack developer community. We’re always listening — to the good, the bad, the confusing, and the wishlist.
​
Prerequisites
Before diving in, make sure the following are in place:
A Fapshi account
Your account is activated
You’ve created a service from your dashboard (this will provide your API Key and API User)
If you’re new to the API, we recommend reviewing the Preliminary Knowledge section first. It contains essential information about authentication, request structure, response formats, and general rules for interacting with the API.
​
What You Can Do with the API
The Fapshi API supports two primary operations:
​
1. Collect Payments
You can collect payments using either:
Initiate Pay: Provides a prebuilt checkout page where your customers complete payments through a Fapshi-hosted interface. Great for rapid setup.
Direct Pay: Offers full control. You’ll build your own payment form and handle validations and user experience on your end, while using our backend to process the transaction.
Read the Direct pay Vs Initiate Pay article to understand the difference between the two and know which one to choose.
​
2. Disburse Funds
Send money to one or multiple mobile money accounts via our disbursement endpoint. This is useful for payouts, salary distribution, or financial services.
You’re now ready to begin! Head over to the Preliminary Knowledge section for details on available on parameters, responses, and usage examples.



API Overview
Create a Service
Learn how to create a service on the Fapshi dashboard to begin collecting or disbursing payments using the API.

To use our API endpoints, you’ll need to create a service. A service is a representation of the service or platform you want to use to collect or disburse payments. You can either create two kinds of service:
Collection Service: This will be used to collect money on your platform. All funds will be reflected in this service on your dashboard.
Disbursement Service: You can use this to issue payouts programmatically on your platform.
You cannot use the same service for both collections and disbursement. If you need both functionalities, you must create two separate services.
By default, payouts are deactivated on Live Mode. So, you have to Contact Support with your API User to request for activation. This should only be done when you have tested the functionality with the test keys.
​
How to Create a Service
Log into your dashboard and click the Merchants dropdown on the extreme left of the menu bar.
Click the “New Service” button.
Fill in the required details and confirm.
The service name is the name of your website or app. - The domain name can be what you have already bought or what you intend to buy. i.e. You must not own it yet. Note that you cannot use fapshi.com or iventily.com as your domain name, since these are Fapshi domains.
Your apikey and apiuser will be generated and will appear at the bottom on the dashboard page. Copy and save it judiciously.
Make sure you keep your API keys private. Never save API keys in your code or on Github. Instead, use environment files and, for an extra level of security, rotate API keys regularly.


Preliminary Knowledge
API Credentials
Learn how to authenticate your API requests to Fapshi using your API User and API Key.

To successfully access any of Fapshi’s developer endpoints, you must include valid API credentials in every request. These credentials authenticate you and ensure secure access to Fapshi services.
​
Overview
API credentials consist of:
apiuser – your unique API user identifier
apikey – a secret key that acts like a password
These two parameters must be included in the headers of your HTTPS requests. If omitted or incorrect, the API will return an authentication error.
​
How to Use Credentials in Requests
Include the apiuser and apikey in the header of every API call like so:
Headers:
apiuser: YOUR_API_USER
apikey: YOUR_API_KEY
This applies to both sandbox and live environments.
​
Security & Responsibility
Your apiuser and apikey combination is essentially your username and password for the Fapshi API. Never share them or expose them in client-side code (like in JavaScript running in the browser). You are fully responsible for any misuse of your credentials.
Misuse of API credentials that results in violations of Fapshi’s Terms & Conditions or Privacy Policy may lead to account suspension or permanent deactivation.




Preliminary Knowledge
Live vs Sandbox Environment
Understand the difference between Fapshi’s test (sandbox) and live environments, and how to switch between them securely.

Fapshi provides two separate environments for developers:
Sandbox (Test) Environment
Live (Production) Environment
Each environment is designed to serve a specific purpose and requires its own credentials and base URL.
​
1. Sandbox Environment (Test Mode)
The Sandbox environment is used for testing and development. It allows you to explore how the Fapshi API works without using real money.
Although no real transactions occur, the API behaves exactly like the live environment, ensuring a seamless transition from testing to production.
​
Key Features
No real funds involved
Identical API behavior as live
Separate credentials and base URL
Ideal for development and integration testing
​
Sandbox Base URL
https://sandbox.fapshi.com
​
Simulating Payments
When testing local payment methods (e.g., Mobile Money), you can simulate success or failure depending on the number used.
​
Test Numbers Table
Status	Provider	Test Numbers
✅ Success	MTN Cameroon	670000000, 670000002, 650000000
Orange Cameroon	690000000, 690000002, 656000000
❌ Failure	MTN Cameroon	670000001, 670000003, 650000001
Orange Cameroon	690000001, 690000003, 656000001
If you use any number not listed above, the transaction outcome will be determined randomly.
​
2. Live Environment (Production Mode)
The Live environment is where real transactions happen. To use this environment:
You must have an activated account
You must create a service
You will receive unique Live API credentials for each service
​
Live Base URL
https://live.fapshi.com
Live API keys are sensitive. You’ll only see your apikey once, so copy and store it safely. You can generate a new key if compromised — this will immediately revoke the old one.
​
Switching From Sandbox to Live
When moving your application from testing to production:
Replace your Sandbox credentials (apiuser and apikey) with your Live credentials
Switch the base URL from: https://sandbox.fapshi.com to https://live.fapshi.com
Double-check your integration for live readiness
Once you switch to the live environment and update your credentials and base URL, you’re good to go!




Preliminary Knowledge
Request Status
Understand how Fapshi API handles successful and failed requests, including response codes and formatting guidelines.

When interacting with the Fapshi Payment API, it’s important to understand how the system responds to different types of requests. This helps in properly handling errors and managing successful transactions within your application.
​
✅ Successful Requests
Any successful request made to the API will return an HTTP status code of 200, indicating that the operation was processed correctly.
The content of the response body will vary depending on the endpoint you called, but you can always expect structured data in a JSON format.
Example response for a successful request:

Copy
{
  "message": "Request successful",
  "link": "https://checkout.fapshi.com/payment/685ac112ea66cd72c5e6cf1e",
  "transId": "ll7J2fl4",
  "dateInitiated": "2025-06-25T11:34:04.450Z" 
}
​
❌ Failed Requests
If something goes wrong, Fapshi will return a 4XX HTTP error code, depending on the nature of the issue:
400 – Bad Request (e.g., missing or malformed parameters)
403 – Forbidden (e.g., invalid credentials)
404 – Not Found (e.g., resource doesn’t exist)
The body of the response will always contain a message field that gives a clear explanation of the failure reason.
Example error response:

Copy
{
  "message": "Invalid API credentials"
}
Make sure to always read the message field of the response to determine the reason for failure and guide your debugging process.
​
🔁 Request Formatting Guidelines
To avoid unexpected failures, keep in mind the following formatting rules:
All request bodies must be JSON encoded.
GET requests must not contain a body. If you include a body in a GET request, the API will immediately return an error.
You can find SDK implementations of all API endpoints in different programming languages in our GitHub SDK repository.






Endpoints
Webhook Integration
Learn how to integrate webhooks to receive real-time payment status updates from Fapshi.

WEBHOOK
/
webhook
/
payment-status
A webhook is an API endpoint made available to external applications that can be called to notify your application whenever a significant event occurs. This allows your app to react or respond immediately to these events.
You can set a webhook URL per service on your Fapshi dashboard. When set, a POST request will be sent to this webhook URL whenever the status of a payment changes to:
SUCCESSFUL — when a payment attempt completes successfully
FAILED — when a payment attempt fails (usually on operator networks like MTN Mobile Money or Orange Money)
EXPIRED — when a payment link expires after 24 hours without successful payment
The body of the webhook request will be the same as the response body returned when querying a payment status.
Your server should respond quickly to webhook requests to avoid timeouts. Fapshi sends only one webhook request per event, regardless of whether your server responds or not.
Response

200

application/json
Acknowledgement of webhook receipt

​
transId
string
Transaction ID of the payment.

​
status
enum<string>
Transaction status

Available options: CREATED, PENDING, SUCCESSFUL, FAILED, EXPIRED 
​
medium
enum<string>
Payment method

Available options: mobile money, orange money 
​
serviceName
string
Name of the service in use

​
amount
integer
Transaction amount

​
revenue
integer
Amount received when Fapshi fees have been deducted

​
payerName
string
Client name

​
email
string<email>
Client email

​
redirectUrl
string<uri>
URL to redirect after payment

​
externalId
string
The transaction ID on your application

​
userId
string
ID of the client on your application

​
webhook
string<uri>
The webhook you defined for your service

​
financialTransId
string
Transaction ID with the payment operator

​
dateInitiated
string<date>
Date when the payment was initiated

​
dateConfirmed
string<date>
Date when the payment was made




ndpoints
Make a Payout
Send money to a user’s mobile money, orange money or fapshi account via a payout-enabled service.

POST
/
payout

Try it
​
Endpoint
POST /payout
Send money to a user’s mobile money, orange money or fapshi account via a payout-enabled service.
After enabling payouts for a service, that service can no longer collect payments. Use separate services for collections and payouts.
​
Parameters
Name	Required	Type	Description
amount	Yes	integer	Amount to send (minimum 100 XAF).
phone	Conditional	string	Recipient phone number (e.g., 67XXXXXXX). Required when medium is not specified or not "fapshi".
medium	No	string	"mobile money", "orange money", or "fapshi". Auto-detected if omitted (requires phone). When set to "fapshi", email is required instead of phone.
name	No	string	Recipient’s name.
email	Conditional	string	Recipient’s email. Required when medium is "fapshi". Optional for payout confirmation receipt when medium is not "fapshi".
userId	No	string	Your system’s user ID for payout tracking (1-100 chars; allowed: a-z, A-Z, 0-9, -, _).
externalId	No	string	Transaction/order ID for reconciliation (1-100 chars; allowed: a-z, A-Z, 0-9, -, _).
message	No	string	Description or reason for payout.
​
Required Fields
When medium is not specified: amount and phone are required.
When medium is "fapshi": amount and email are required.
​
Sandbox Testing
When testing payouts with medium set to "fapshi" in the sandbox environment:
Emails that always return successful transactions: test.success@fapshi.com and messi.champion@fapshi.com
Emails that always return failed transactions: test.failed@fapshi.com and penaldo.test@fapshi.com
Other emails: Transaction status will be determined in a stochastic (random) manner
Authorizations
​
apiuser
stringheaderrequired
​
apikey
stringheaderrequired
Body
application/json
​
amount
integerrequired
Amount to send (minimum 100 XAF).

Required range: x >= 100
​
phone
string
Recipient phone number. Required when medium is not specified or not "fapshi". Not required when medium is "fapshi".

​
medium
enum<string>
Payment medium (optional). Auto-detected if omitted (requires phone). When set to "fapshi", email is required instead of phone.

Available options: mobile money, orange money, fapshi 
​
name
string
Recipient name (optional).

​
email
string<email>
Recipient email. Required when medium is "fapshi". Optional for payout receipt when medium is not "fapshi".

​
userId
string
User ID for payout tracking (optional).

​
externalId
string
Transaction/order ID for reconciliation (optional).

​
message
string
Reason for payout (optional).

Response

200

application/json
Accepted

​
message
string
Success message

​
transId
string
Transaction ID for the payment.

​
dateInitiated
string<date>
Date when the payment was initiated.



Endpoints
Get Service Balance
Returns the current balance of the service account.

GET
/
balance

Try it
​
Endpoint
GET /balance
Returns the current balance of the service account.
Balance in sandbox environment is randomly generated on each request.
Authorizations
​
apiuser
stringheaderrequired
​
apikey
stringheaderrequired
Response
200 - application/json
Current balance returned

​
service
string
The service whose balance you've queried.

​
balance
integer
Current balance amount.

​
currency
string
Currency.



Endpoints
Search Transactions
Search for transactions using various filter criteria.

GET
/
search

Try it
​
Endpoint
GET /search
Search for transactions based on criteria.
​
Query Parameters
Name	Description	Allowed Values
status	Filter transactions by status.	created, successful, failed, expired
medium	Filter by payment medium.	mobile money, orange money
start	Start date (YYYY-MM-DD) for filtering initiated transactions.	Date format
end	End date (YYYY-MM-DD) for filtering initiated transactions.	Date format
amt	Exact amount to filter by.	Integer
limit	Maximum number of results (default 10).	1 to 100
sort	Sort order: asc or desc. Defaults to descending (most recent first).	asc, desc
Invalid query parameter values are ignored.
Authorizations
​
apiuser
stringheaderrequired
​
apikey
stringheaderrequired
Query Parameters
​
status
enum<string>
Filter by transaction status.

Available options: created, successful, failed, expired 
​
medium
enum<string>
Filter by payment medium.

Available options: mobile money, orange money 
​
start
string<date>
Start date (YYYY-MM-DD).

​
end
string<date>
End date (YYYY-MM-DD).

​
amt
integer
Exact amount to filter.

​
limit
integerdefault:10
Maximum number of results.

Required range: 1 <= x <= 100
​
sort
enum<string>default:desc
Sort order.

Available options: asc, desc 
Response

200

application/json
Filtered list of transactions

​
transId
string
Transaction ID of the payment.

​
status
enum<string>
Transaction status

Available options: CREATED, PENDING, SUCCESSFUL, FAILED, EXPIRED 
​
medium
enum<string>
Payment method

Available options: mobile money, orange money 
​
serviceName
string
Name of the service in use

​
amount
integer
Transaction amount

​
revenue
integer
Amount received when Fapshi fees have been deducted

​
payerName
string
Client name

​
email
string<email>
Client email

​
redirectUrl
string<uri>
URL to redirect after payment

​
externalId
string
The transaction ID on your application

​
userId
string
ID of the client on your application

​
webhook
string<uri>
The webhook you defined for your service

​
financialTransId
string
Transaction ID with the payment operator

​
dateInitiated
string<date>
Date when the payment was initiated

​
dateConfirmed
string<date>





Endpoints
Get Transactions by User ID
Retrieve all transactions associated with a specific user ID.

GET
/
transaction
/
{userId}

Try it
​
Endpoint
GET /transaction/:userId
Retrieve all transactions associated with a specific user ID.
Returns an array of transaction objects related to the specified user.
Authorizations
​
apiuser
stringheaderrequired
​
apikey
stringheaderrequired
Path Parameters
​
userId
stringrequired
User ID to retrieve transactions for.

Response

200

application/json
List of transactions

​
transId
string
Transaction ID of the payment.

​
status
enum<string>
Transaction status

Available options: CREATED, PENDING, SUCCESSFUL, FAILED, EXPIRED 
​
medium
enum<string>
Payment method

Available options: mobile money, orange money 
​
serviceName
string
Name of the service in use

​
amount
integer
Transaction amount

​
revenue
integer
Amount received when Fapshi fees have been deducted

​
payerName
string
Client name

​
email
string<email>
Client email

​
redirectUrl
string<uri>
URL to redirect after payment

​
externalId
string
The transaction ID on your application

​
userId
string
ID of the client on your application

​
webhook
string<uri>
The webhook you defined for your service

​
financialTransId
string
Transaction ID with the payment operator

​
dateInitiated
string<date>
Date when the payment was initiated

​
dateConfirmed
string<date>
Date when the payment was made






Endpoints
Expire a Payment Transaction
Expire a payment link to prevent further payments.

POST
/
expire-pay

Try it
​
Endpoint
POST /expire-pay
Expire a payment link to prevent further payments.
​
Parameters
Name	Required	Type	Description
transId	Yes	string	ID of the transaction to expire
​
Response
Returns details of the expired transaction if successful.
Returns 400 Bad Request with message "Link already expired" if the transaction was already expired.
Authorizations
​
apiuser
stringheaderrequired
​
apikey
stringheaderrequired
Body
application/json
​
transId
stringrequired
Transaction ID to expire.

Response

200

application/json
Payment link expired successfully

​
transId
string
Transaction ID of the payment.

​
status
enum<string>
Transaction status

Available options: EXPIRED 
​
medium
enum<string>
Payment method

Available options: mobile money, orange money 
​
serviceName
string
Name of the service in use

​
amount
integer
Transaction amount

​
revenue
integer
Amount received when Fapshi fees have been deducted

​
payerName
string
Client name

​
email
string<email>
Client email

​
redirectUrl
string<uri>
URL to redirect after payment

​
externalId
string
The transaction ID on your application

​
userId
string
ID of the client on your application

​
webhook
string<uri>
The webhook you defined for your service

​
financialTransId
string
Transaction ID with the payment operator

​
dateInitiated
string<date>
Date when the payment was initiated

​
dateConfirmed
string<date>
Date when the payment was made







Endpoints
Get Payment Transaction Status
Retrieve the status of a payment transaction using its transaction ID.

GET
/
payment-status
/
{transId}

Try it
​
Endpoint
GET /payment-status/:transId
Check the status of a payment by transaction ID.
​
Status Values
Status	Meaning
CREATED	Payment not yet attempted.
PENDING	User is in process of payment.
SUCCESSFUL	Payment completed successfully.
FAILED	Payment failed.
EXPIRED	This means 24 hours have passed since the payment link was generated and no successful payment attempt was made in that time interval OR the link got manually expired to prevent payment.
No payments can be made after the status is SUCCESSFUL or EXPIRED.
Authorizations
​
apiuser
stringheaderrequired
​
apikey
stringheaderrequired
Path Parameters
​
transId
stringrequired
Transaction ID of the payment.

Response

200

application/json
Payment status retrieved successfully

​
transId
string
Transaction ID of the payment.

​
status
enum<string>
Transaction status

Available options: CREATED, PENDING, SUCCESSFUL, FAILED, EXPIRED 
​
medium
enum<string>
Payment method

Available options: mobile money, orange money 
​
serviceName
string
Name of the service in use

​
amount
integer
Transaction amount

​
revenue
integer
Amount received when Fapshi fees have been deducted

​
payerName
string
Client name

​
email
string<email>
Client email

​
redirectUrl
string<uri>
URL to redirect after payment

​
externalId
string
The transaction ID on your application

​
userId
string
ID of the client on your application

​
webhook
string<uri>
The webhook you defined for your service

​
financialTransId
string
Transaction ID with the payment operator

​
dateInitiated
string<date>
Date when the payment was initiated

​
dateConfirmed
string<date>
Date when the payment was made








Endpoints
Initiate a Direct Payment Request
Send a payment request directly to a user’s mobile device.

POST
/
direct-pay

Try it
​
Endpoint
POST /direct-pay
Send a payment request directly to a user’s mobile device. You are responsible for building your own checkout and verifying payment status.
Direct payment transactions cannot and do not expire. Consequently, their final state is either SUCCESSFUL or FAILED.

**Status for PrepSkul Account**: ✅ Direct Pay has been **APPROVED and ACTIVATED** for this account in production. Direct Pay and Disbursements are both operational.

**Note**: Direct pay is disabled by default on live environment for new accounts. For this account, activation has been completed. If you encounter Direct Pay errors, they would be unexpected edge cases.

Handle this endpoint with care; misuse can result in account suspension.
​
Parameters
Name	Required	Type	Description
amount	Yes	integer	Amount to be paid (minimum 100 XAF).
phone	Yes	string	Phone number to request payment from (e.g., 67XXXXXXX).
medium	No	string	"mobile money" or "orange money". Omit to auto-detect.
name	No	string	Payer’s name.
email	No	string	Payer’s email to receive receipt.
userId	No	string	Your system’s user ID (1–100 chars; a–z, A–Z, 0–9, -, _).
externalId	No	string	Transaction/order ID for reconciliation (1–100 chars; a–z, A–Z, 0–9, -, _).
message	No	string	Reason for payment.
​
Response
200 OK with JSON body containing:
message: success message
transId: transaction ID to track payment status
dateInitiated: date when the payment was initiated
Errors return 4XX with failure message.
Authorizations
​
apiuser
stringheaderrequired
​
apikey
stringheaderrequired
Body
application/json
​
amount
integerrequired
Amount to be paid (minimum 100 XAF).

Required range: x >= 100
​
phone
stringrequired
Phone number where payment request is sent.

​
medium
enum<string>
Payment medium (optional).

Available options: mobile money, orange money 
​
name
string
Name of the payer (optional).

​
email
string<email>
Email of the payer for receipts (optional).

​
userId
string
Internal user ID (optional).

​
externalId
string
Transaction/order ID for reconciliation (optional).

​
message
string
Reason for payment (optional).

Response

200

application/json
Accepted

​
message
string
Success message

​
transId
string
Transaction ID for the payment.

​
dateInitiated
string<date>
Date when the payment was initiated.





Endpoints
Generate a Payment Link
Create a payment link to redirect users to a Fapshi-hosted checkout page.

POST
/
initiate-pay

Try it
​
Endpoint
POST /initiate-pay
Generate a payment link where users complete payment on a prebuilt Fapshi checkout page.
​
Parameters
Name	Required	Type	Description
amount	Yes	integer	Amount to be paid (minimum 100 XAF).
email	No	string	If set, the user won’t have to provide an email during payment.
redirectUrl	No	string	URL to redirect the user after payment.
userId	No	string	Your internal user ID (1-100 chars; a-z, A-Z, 0-9, -, _).
externalId	No	string	Transaction/order ID for reconciliation (1-100 chars; a-z, A-Z, 0-9, -, _).
message	No	string	Reason for payment.
​
Response
200 OK with JSON body containing:
message: success message
link: URL for user payment
transId: transaction ID to track payment status
dateInitiated: date when the payment was initiated
Errors return 4XX with a message explaining the failure.
Payment links expire after 24 hours and cannot be used afterward.
Authorizations
​
apiuser
stringheaderrequired
​
apikey
stringheaderrequired
Body
application/json
​
amount
integerrequired
Amount to be paid (minimum 100 XAF).

Required range: x >= 100
​
email
string<email>
Optional user email to skip during payment.

​
redirectUrl
string<uri>
URL to redirect after payment.

​
userId
string
Internal user ID (1-100 chars; a-z, A-Z, 0-9, -, _).

​
externalId
string
Transaction/order ID for reconciliation (1-100 chars; a-z, A-Z, 0-9, -, _).

​
message
string
Reason for payment.

Response

200

application/json
Payment link generated successfully

​
message
string
Success message

​
link
string<uri>
URL to redirect the user to complete payment.

​
transId
string
Transaction ID for payment.

​
dateInitiated
string<date>
Date when the payment was initiated.