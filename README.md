# Common Lisp  Amazon SQS Client 

## Installation
Since this code is not in quicklisp dists you need to manually download code and then load it with quicklisp or asdf

```
CL-USER> (push "/tmp/amazonsqs/" asdf:*central-registry*)
("/tmp/amazonsqs/" #P"/Users/milan/quicklisp/quicklisp/")
CL-USER> (ql:quickload "amazonsqs")
.......
("amazonsqs")
CL-USER> (use-package :amazonsqs)
T
```

## Usage example

Create aws credentials

```
CL-USER> (defparameter *creds* (make-instance 'awscredentials :access-key "ACCESS_KEY" :secret-key "SECRET_KEY"))
*CREDS*
````
then SQS
```
CL-USER> (defparameter *mysqs* (make-instance 'sqs :aws-credentials *creds*))
*MYSQS*
````
or use PARALLEL-SQS which is caching and reusing connections (one connection per thread, considerably   faster then SQS)
```
CL-USER> (defparameter *mysqs* (make-instance 'parallel-sqs :aws-credentials *creds*))
*MYSQS*
````

### Basic Queue Operations

List queues
```
CL-USER> (list-queues :sqs *mysqs*)
NIL
#<RESPONSE 200>
CL-USER> (setf *sqs* *mysqs*)
CL-USER> (list-queues)
NIL
```
Create queue
```
CL-USER> (create-queue "testQueue" :attributes '((:name "DelaySeconds" :value 5)))
"http://sqs.us-east-1.amazonaws.com/653067390209/testQueue"
#<RESPONSE 200>
CL-USER> (list-queues)
("http://sqs.us-east-1.amazonaws.com/653067390209/testQueue")
#<RESPONSE 200>
```

Getting queue url and attributes
```
CL-USER> (get-queue-url "testQueue")
"http://sqs.us-east-1.amazonaws.com/653067390209/testQueue"
#<RESPONSE 200>
CL-USER> (get-queue-attributes (get-queue-url "testQueue") '("DelaySeconds"))
(("DelaySeconds" . "5"))
#<RESPONSE 200>
CL-USER> (get-queue-attributes (get-queue-url "testQueue") '("All"))
(("QueueArn" . "arn:aws:sqs:us-east-1:653067390209:testQueue")
 ("ApproximateNumberOfMessages" . "0")
 ("ApproximateNumberOfMessagesNotVisible" . "0")
 ("ApproximateNumberOfMessagesDelayed" . "0")
 ("CreatedTimestamp" . "1449321474") ("LastModifiedTimestamp" . "1449321474")
 ("VisibilityTimeout" . "30") ("MaximumMessageSize" . "262144")
 ("MessageRetentionPeriod" . "345600") ("DelaySeconds" . "5")
 ("ReceiveMessageWaitTimeSeconds" . "0"))
#<RESPONSE 200>
```
Delete queue
```
CL-USER> (delete-queue (get-queue-url "testQueue"))
#<RESPONSE 200>
```

### Sending and receiving messages

Sending one message
```
CL-USER> (send-message (get-queue-url "testQueue") "example message body" :attributes '((:name "MessageAttribute-1" :value 10 :type :number)))
((:MESSAGE-ID . "c6e4e2d8-f25a-4eea-8b9d-5b6dcd094530")
 (:ATTRIBUTES-MD5 . "909bdca3008941c20f265b588e20579a")
 (:BODY-MD5 . "337b359654178adbf8782b837261ff66"))
#<RESPONSE 200>
```
Receive and delete message
```
CL-USER> (defparameter *queue-url* (get-queue-url "testQueue"))
*QUEUE-URL*
CL-USER> (receive-message *queue-url* :max 10 :attributes '("All") :message-attributes '("MessageAttribute-1"))
(#<MESSAGE examp... {10092419D3}>)
#<RESPONSE 200>
CL-USER> (defparameter *received-msgs* *)
*RECEIVED-MSGS*
CL-USER> (first *received-msgs*)
#<MESSAGE examp... {1004409383}>
CL-USER> (message-body (first *received-msgs*))
"example message body"
CL-USER> (message-attributes (first *received-msgs*))
(#<MESSAGE-ATTRIBUTE MessageAttribute-1>)
CL-USER> (attributes (first *received-msgs*))
(("SentTimestamp" . "1449321567628") ("ApproximateReceiveCount" . "2")
 ("ApproximateFirstReceiveTimestamp" . "1449321656050")
 ("SenderId" . "AIDAJC4FX3MM62J3KPCT4"))
 CL-USER> (delete-message *queue-url* (message-receipt-handle (first *received-msgs*)))
#<RESPONSE 200>
```

Sending more than one message in one request

```
CL-USER> (send-message-batch *queue-url* '((:id "id1" :body "1. msg body")
					   (:id "id2" :body "2. msg body" :delay-seconds 10)
					   (:id "id3" :body "3. msg body" :attributes ((:name "attr1" :type :number :value 10)))))


#<BATCH-REQUEST-RESULT :successful 3, failed: 0 {1003CF87C3}>
#<RESPONSE 200>
CL-USER> 
CL-USER> (successful *)
(#<SEND-MESSAGE-BATCH-RESULT id1> #<SEND-MESSAGE-BATCH-RESULT id2>
 #<SEND-MESSAGE-BATCH-RESULT id3>)
```
or the same thing with CLOS objects
```
CL-USER> (defparameter *send-message-action* (make-instance 'send-message-batch-action))
*SEND-MESSAGE-ACTION*
CL-USER> (add-message-entry *send-message-action* (make-instance 'batch-message-entry :id "id100"  :body "another msg"))

(#<BATCH-MESSAGE-ENTRY {1006C78923}>)
CL-USER> (add-message-entry *send-message-action* (make-instance 'batch-message-entry :id "id200"  :body "another msg"
								 :attributes (list
									      (make-instance 'message-attribute 
											     :type :string
											     :value "foo"
											     :name "AttrBatchName"))))
(#<BATCH-MESSAGE-ENTRY {1007007903}> #<BATCH-MESSAGE-ENTRY {1006C78923}>)
CL-USER> (send-message-batch *queue-url* *send-message-action*)
#<BATCH-REQUEST-RESULT :successful 2, failed: 0 {10043C1383}>
#<RESPONSE 200>
CL-USER> 

```
deleting more than one message
```
CL-USER> (defparameter *received-messages* (receive-message *queue-url* :max 5))
*RECEIVED-MESSAGES*
CL-USER> (defparameter *delete-message-batch-action* (make-instance 'delete-message-batch-action))
*DELETE-MESSAGE-BATCH-ACTION*
CL-USER> (add-message-entry *delete-message-batch-action* 
			    (make-instance 'batch-message-delete-entry 
					   :id "message-1"
					   :receipt-handle (message-receipt-handle (first *received-messages*))))
(#<BATCH-MESSAGE-DELETE-ENTRY {1008A49A13}>)
CL-USER> (add-message-entry *delete-message-batch-action* 
			    (make-instance 'batch-message-delete-entry 
					   :id "message-2"
					   :receipt-handle (message-receipt-handle (second *received-messages*))))
(#<BATCH-MESSAGE-DELETE-ENTRY {1008A70AB3}>
 #<BATCH-MESSAGE-DELETE-ENTRY {1008A49A13}>)
 CL-USER> (delete-message-batch *queue-url* *delete-message-batch-action*)
#<BATCH-REQUEST-RESULT :successful 2, failed: 0 {100A1C1383}>
#<RESPONSE 200>
CL-USER> (successful *)
(#<DELETE-MESSAGE-BATCH-RESULT message-1>
 #<DELETE-MESSAGE-BATCH-RESULT message-2>)
CL-USER> 
```
the same without CLOS
```
CL-USER> (delete-message-batch *queue-url* `((:id "ID1" :receipt-handle ,(message-receipt-handle (first *received-messages*)))
					     (:id "ID2" :receipt-handle ,(message-receipt-handle (second *received-messages*)))))
#<BATCH-REQUEST-RESULT :successful 2, failed: 0 {10049BA243}>
#<RESPONSE 200>
CL-USER> (successful *)
(#<DELETE-MESSAGE-BATCH-RESULT ID1> #<DELETE-MESSAGE-BATCH-RESULT ID2>)
CL-USER> 
```


## The AMAZONSQS Dictionary:

**NOTE** All methods/functions described here that operates on Amazon SQS are are directly mapped to Actions from [Amazon SQS documentation](http://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_Operations.html)

### Classes
*class*
**SQS**

Thread safe SQS client (new connection for every request)

*slot* **aws-credentials**
*slot* **region** (defualt is sqs.us-east-1.amazonaws.com)
*slot* **protocol** (default is :http)

*class*
**PARALLEL-SQS**
Thread safe SQS client that caches connections (one per thread). Slots are as in SQS
Same slots as in SQS


### Functions/Methods
*function*
**add-permission** queue-url label permissions &key sqs => response

queue-url --- a string representing queue url

label --- a string representing permission you're setting

permissions --- a list of permission plists ((:aws-account-id "account-id" :action-name "action-name"))

response --- RESPONSE object

Example:
```
(add-permission "queue-url" "label" '((:account-id "acc-id" :action-name "Action")))
```

**change-message-visibility** queue-url receipt-handle visibility-timeout &key sqs => response

**change-message-visibility-batch** queue-url entries &key sqs =>

**create-queue** queue-name &key attributes sqs => 

**delete-message** queue-url receipt-handle &key sqs =>

**delete-message-batch** queue-url entries &key sqs =>

**delete-queue** queue-url &key sqs => response

**get-queue-attributes** queue-url attributes &key sqs =>

**get-queue-url** queue-name &key sqs =>

**list-dead-letter-source-queues** queue-url &key sqs =>

**list-queues** &key prefix sqs =>

**purge-queue** queue-url &key sqs =>

**receive-message** queue-url &key max visibility-timeout wait-time attributes message-attributes sqs =>

**remove-permission** queue-url label &key sqs =>

**send-message** queue-url message-body &key delay-seconds attributes sqs =>

**send-message-batch** queue-url entries &key sqs =>

**set-queue-attributes** queue-url attribute-name attribute-value &key sqs =>