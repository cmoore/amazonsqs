;;;;
;;;; Copyright (c) Milan Jovanovic <milanj@gmail.com>
;;;;
;;;; Redistribution and use in source and binary forms, with or without
;;;; modification, are permitted provided that the following conditions
;;;; are met:
;;;;
;;;;   * Redistributions of source code must retain the above copyright
;;;;     notice, this list of conditions and the following disclaimer.
;;;;
;;;;   * Redistributions in binary form must reproduce the above
;;;;     copyright notice, this list of conditions and the following
;;;;     disclaimer in the documentation and/or other materials
;;;;     provided with the distribution.
;;;;
;;;; THIS SOFTWARE IS PROVIDED BY THE AUTHOR 'AS IS' AND ANY EXPRESSED
;;;; OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
;;;; WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
;;;; ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
;;;; DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
;;;; DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
;;;; GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
;;;; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
;;;; WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
;;;; NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
;;;; SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;;;;
;;;; utils.lisp

(in-package #:amazonsqs)

(defun iso8601-time (&optional (offset 0) (time (get-universal-time)) (zone 0))
  "Return amazon time format"
  (multiple-value-bind (seconds minutes hour date month year) (decode-universal-time (+ offset time) zone)
    (format nil "~d-~2,'0d-~2,'0dT~2,'0d:~2,'0d:~2,'0dZ" year month date hour minutes seconds)))

(defun sign-string (string secret-key)
  (cl-base64:usb8-array-to-base64-string  
   (ironclad:hmac-digest 
    (ironclad:update-hmac 
     (ironclad:make-hmac (babel:string-to-octets secret-key :encoding :utf-8) :sha256)
     (babel:string-to-octets string :encoding :utf-8)))))

(defun remove-blanks (string)
  (string-trim #(#\Space #\Newline #\Backspace #\Tab #\Linefeed #\Page #\Return #\Rubout)
	       string))

;;; http://tools.ietf.org/html/rfc3986#page-13
;;; unreserved  = ALPHA / DIGIT / "-" / "." / "_" / "~"
(defun is-unreserved (code)
  (declare (fixnum code))  
  (or (and (>= code 65) (<= code 90))
      (and (>= code 97) (<= code 122))
      (and (>= code 48) (<= code 57))
      (or (= code 45) (= code 46)
	  (= code 95) (= code 126))))

(defun amazon-encode (string)
  (let* ((string (if (stringp string) string (format nil "~a" string)))
	 (bytes (babel:string-to-octets string :encoding :utf-8))
	 (*print-pretty* nil))
    (with-output-to-string (s)
      (loop for code across bytes
	    if (is-unreserved code)
	      do (write-char (code-char code) s)
	    else do (format s "%~2,'0X" code)))))

(defun alist-if-not-nil (&rest rest)
  (loop for (a b) on rest by #'cddr
	when b collecting (cons  a b) into result
	  finally (return result)))

(defun find-n-char-match (string n char-match &optional (index 0) (found 0))
  (cond ((= n found)
	 (1- index))
	((> index (1- (length string)))
	 nil)
	(t
	 (let ((char (char string index)))
	   (if (char-equal char char-match)
	       (find-n-char-match string n char-match (1+ index) (1+ found))
	       (find-n-char-match string n char-match (1+ index) found))))))

(defun to-alist (l)
  (loop for (key value) on l by #'cddr
	collect (cons key value)))

(defun reverse-and-count (list)
  (if (null list)
      (values nil 0)
      (loop for l in list
	    for count from 1
	    with result
	    do
	       (setf result (cons l result))
	    finally (return (values result count)))))
