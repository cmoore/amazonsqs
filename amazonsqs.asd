;;;; amazonsqs.asd

(asdf:defsystem #:amazonsqs
  :description "Amazon Simple Queue Service CL client"
  :author "Milan Jovanovic <milanj@gmail.com>"
  :license "BSD"
  :version "0.0.1"
  :serial t
  :depends-on (#:drakma #:cxml #:alexandria #:ironclad #:bordeaux-threads)
  :components ((:file "package")
	       (:file "amazonsqs")
	       (:file "utils")
	       (:file "errors")
	       (:file "objects")
	       (:file "schemas")
	       (:file "parser")
	       (:file "connpool")
	       (:file "request")
	       (:file "parameters")
	       (:file "api")))
