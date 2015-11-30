(in-package :amazonsqs)

(defclass request ()
  ((action :initarg :action :accessor request-action)
   (parameters :initarg :parameters :accessor request-parameters :initform nil)
   (queue-url :initarg :queue-url :accessor request-query-url :initform nil)))

(defgeneric get-request-host (sqs request)
  (:documentation "This function return endpoint host for our request"))

(defgeneric sign-request (sqs request)
  (:documentation "This function resolve all missing Amazon SQS parameters and sign request adding Signature param to request parameters"))

(defgeneric process-request (sqs request)
  (:documentation "Generic function that do real work of sending request to amazon and returning something meaningful"))

(defgeneric test-request (sqs request)
  (:documentation "For testing purposes, return response string"))

(defmethod get-request-host ((sqs sqs) (request request))
  (let ((query-url (request-query-url request)))
    (if query-url
	query-url
	(concatenate 'string
		     (if (eq (sqs-protocol sqs) :https)
			 "https://"
			 "http://")
		     (sqs-region sqs)))))

(defmethod sign-request ((sqs sqs) (request request))
  (let* ((parameters (request-parameters request))
	 (full-parameters (add-base-parameters-and-encode sqs parameters (request-action request)))
	 (sorted-full-parameters (sort full-parameters #'string< :key #'car))
	 (parameters-as-string (parameters-to-string sorted-full-parameters))
	 (canonical-string (create-canonical-string parameters-as-string
						    (sqs-region sqs)
						    (get-request-host sqs request)
						    (sqs-protocol sqs)))
	 (signature (sign-string canonical-string (secret-key (sqs-aws-credentials sqs)))))
    (setf (request-parameters request)
	  (acons "Signature" (amazon-encode signature) sorted-full-parameters))))

(defun no-encoder (parameter-value encoding)
  (declare (ignore encoding))
  parameter-value)

(defmethod process-request ((sqs sqs) (request request))
  (let ((signed-parameters (sign-request sqs request)))
    (multiple-value-bind (amazon-stream response-status-code)
	(drakma:http-request (get-request-host sqs request)
			     :parameters signed-parameters
			     :method :post
			     :url-encoder #'no-encoder
			     :want-stream t
			     :force-binary t)
      (multiple-value-bind (f s) (create-response (cxml:make-source amazon-stream))
	(if s
	    (values f (make-instance 'response :request-id s :status response-status-code))
	    (make-instance 'response :request-id f :status response-status-code))))))

(defmethod process-request ((sqs parallel-sqs) (request request))
  (let ((signed-parameters (sign-request sqs request))
	(cached-stream (get-sqs-stream sqs)))
    (multiple-value-bind (response response-status-code ign1 ign2 stream)
	(http-call (get-request-host sqs request) signed-parameters cached-stream)	
      (declare (ignore ign1 ign2))
      (unless (eq cached-stream stream)
	(cache-sqs-stream sqs stream))
      (multiple-value-bind (f s) (create-response  (cxml:make-source response))
	(if s
	    (values f (make-instance 'response :request-id s :status response-status-code))
	    (make-instance 'response :request-id f :status response-status-code))))))

(defun http-call (hostname parameters saved-stream)
  (flet ((drakma-call (stream)
	   (drakma:http-request hostname
				:parameters parameters
				:method :post
				:url-encoder #'no-encoder
				:close nil
				:stream stream)))
    (handler-case
	(drakma-call saved-stream)
      ((or stream-error cl+ssl::ssl-error) ()
	(drakma-call nil)))))

(defmethod test-request ((sqs sqs) (request request))
  (let ((signed-parameters (sign-request sqs request)))
    (drakma:http-request (get-request-host sqs request)
			 :parameters signed-parameters
			 :method :post
			 :url-encoder #'no-encoder
			 :close nil)))

(defun create-canonical-string (url region host protocol)
  ;; looks like we don't need regions:443 if protocol is https
  (declare (ignore protocol))
  (let* ((extra-dash-index (find-n-char-match host 3 #\/))
	 (extra-path (and extra-dash-index (subseq host extra-dash-index))))
    (format nil "~A~%~A~%~A~%~A"
	    "POST" region 
	    (if extra-path extra-path "/") url)))

(defun add-base-parameters-and-encode (sqs params action)
  (append `(("Action" . ,(amazon-encode action))
	    ("Version" . ,(amazon-encode +api-version+))
	    ("AWSAccessKeyId" . ,(amazon-encode (access-key (sqs-aws-credentials sqs))))
	    ("SignatureVersion" . ,(amazon-encode +signature-version+))
	    ("SignatureMethod" . ,(amazon-encode +signature-method+))
	    ("Timestamp" . ,(amazon-encode (iso8601-time))))
	  (mapcar (lambda (cons)
		    (cons (amazon-encode (car cons))
			  (amazon-encode (cdr cons))))
		  params)))

(defun parameters-to-string (parameters)
  (let ((*print-pretty* nil))
    (with-output-to-string (s)
      (loop for (key . value) in parameters
	    for index  from 0
	    do
	       (format s "~:[~;&~]~A=~A"(> index 0) key value)))))