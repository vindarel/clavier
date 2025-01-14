(in-package #:clavier)

(defvar *signal-validation-errors* nil)

(defvar *whitespaces* (list #\Backspace #\Tab #\Linefeed #\Newline #\Vt #\Page
                            #\Return #\Space #\Rubout
                            #+sbcl #\Next-Line #-sbcl (code-char 133)
                            #+sbcl #\No-break_space)
  ;; see updates on cl-str
  "Characters representing a whitespace. On some implementations, linefeed and newline represent the same character (code).")

(defun call-with-signal-validation-errors (func &optional (signal t))
  (let ((*signal-validation-errors* signal))
    (funcall func)))

(defmacro with-signal-validation-errors ((&optional (signal t)) &body body)
  "Enables/disables validation errors in body

   Args: - signal(boolean) : If **T**, errors are signaled. If **NIL**, they are not."
  `(call-with-signal-validation-errors (lambda () ,@body) ,signal))

(defmacro collecting-validation-errors ((errors found-p) expr &body body)
  `(multiple-value-bind (,errors ,found-p)
       (%collecting-validation-errors
        (lambda () ,expr))
     ,@body))

(define-condition validation-error (error)
  ((target :initarg :target
           :initform (error "Set up the target")
           :reader validation-error-target)
   (error-msg :initarg :error-msg
              :initform (error "Provide the error message")
              :reader validation-error-message))
  (:report (lambda (c s)
             (format s "~A" (validation-error-message c)))))

(defmethod print-object ((validation-error validation-error) stream)
  (print-unreadable-object (validation-error stream :type t :identity t)
    (format stream "~A: ~A"
            (validation-error-target validation-error)
            (validation-error-message validation-error))))

(defun validation-error (target error-msg &rest args)
  (cerror "Skip validation"
          'validation-error
          :target target
          :error-msg (apply #'format nil (cons error-msg args))))

(defun %collecting-validation-errors (func)
  (let ((errors nil))
    (handler-bind
        ((validation-error
           (lambda (c)
             (push c errors)
             (continue c))))
      (funcall func))
    (values errors (plusp (length errors)))))

(defclass validator (closer-mop:funcallable-standard-object)
  ((message :initarg :message
            :accessor message
            :type (or null string function)
            :initform (error "Provide the validation error message")))
  (:metaclass closer-mop:funcallable-standard-class))

(defmethod initialize-instance :after ((validator validator) &rest initargs)
  (declare (ignorable initargs))
  (closer-mop:set-funcallable-instance-function
   validator
   (lambda (&rest args)
     (apply #'validate validator args))))

(defclass validator-collection (validator)
  ((validators :initarg :validators
               :accessor validators
               :initform nil))
  (:metaclass closer-mop:funcallable-standard-class)
  (:default-initargs :message (lambda (&rest args)
                                (declare (ignorable args))
                                "")))

(defclass equal-to-validator (validator)
  ((object :initarg :object
           :accessor object
           :initform (error "Provide the object")))
  (:default-initargs
   :message
   (lambda (validator object)
     (format nil "~A is not equal to ~A" object (object validator))))
  (:metaclass closer-mop:funcallable-standard-class))

(defclass not-equal-to-validator (validator)
  ((object :initarg :object
           :accessor object
           :initform (error "Provide the object")))
  (:default-initargs
   :message
   (lambda (validator object)
     (format nil "~A is equal to ~A" object (object validator))))
  (:metaclass closer-mop:funcallable-standard-class))

(defclass blank-validator (validator)
  ()
  (:default-initargs
   :message (lambda (validator object)
              (declare (ignorable validator object))
              (format nil "Should be blank")))
  (:metaclass closer-mop:funcallable-standard-class))

(defclass not-blank-validator (validator)
  ()
  (:default-initargs
   :message (lambda (validator object)
              (declare (ignorable validator object))
              (format nil "Should not be blank")))
  (:metaclass closer-mop:funcallable-standard-class))

(defclass true-validator (validator)
  ()
  (:default-initargs
   :message (lambda (validator object)
              (declare (ignorable validator object))
              (format nil "Is not true")))
  (:metaclass closer-mop:funcallable-standard-class))

(defclass false-validator (validator)
  ()
  (:default-initargs
   :message (lambda (validator object)
              (declare (ignorable validator object))
              (format nil "Is not false")))
  (:metaclass closer-mop:funcallable-standard-class))

(defclass type-validator (validator)
  ((type :initarg :type
         :accessor validator-type
         :initform (error "Provide the type")))
  (:default-initargs
   :message (lambda (validator object)
              (format nil "~A is not of type ~A" object (validator-type validator))))
  (:metaclass closer-mop:funcallable-standard-class))

(defclass string-validator (type-validator)
  ()
  (:default-initargs
   :type 'string
   :message (lambda (validator object)
              (declare (ignore validator))
              (format nil "~S is not a string" object)))
  (:metaclass closer-mop:funcallable-standard-class))

(defclass boolean-validator (type-validator)
  ()
  (:default-initargs
   :type 'boolean
   :message (lambda (validator object)
              (declare (ignorable validator))
              (format nil "~A is not a boolean" object)))
  (:metaclass closer-mop:funcallable-standard-class))

(defclass integer-validator (type-validator)
  ()
  (:default-initargs
   :type 'integer
   :message (lambda (validator object)
              (declare (ignorable validator))
              (format nil "~A is not an integer" object)))
  (:metaclass closer-mop:funcallable-standard-class))

(defclass symbol-validator (type-validator)
  ()
  (:default-initargs
   :type 'symbol
   :message (lambda (validator object)
              (declare (ignorable validator))
              (format nil "~A is not a symbol" object)))
  (:metaclass closer-mop:funcallable-standard-class))

(defclass keyword-validator (type-validator)
  ()
  (:default-initargs
   :type 'keyword
   :message (lambda (validator object)
              (declare (ignorable validator))
              (format nil "~A is not a keyword" object)))
  (:metaclass closer-mop:funcallable-standard-class))

(defclass list-validator (type-validator)
  ()
  (:default-initargs
   :type 'list
   :message (lambda (validator object)
              (declare (ignorable validator))
              (format nil "~A is not a list" object)))
  (:metaclass closer-mop:funcallable-standard-class))


(defclass function-validator (validator)
  ((function :initarg :function
             :accessor validator-function
             :initform (error "Provide the function")))
  (:metaclass closer-mop:funcallable-standard-class))

(defclass email-validator (validator)
  ()
  (:default-initargs
   :message (lambda (validator object)
              (declare (ignorable validator))
              (format nil "The email is invalid: ~A" object)))
  (:metaclass closer-mop:funcallable-standard-class))

(defclass regex-validator (validator)
  ((regex :initarg :regex
          :initform (error "Provide the regex")
          :accessor validator-regex))
  (:default-initargs
   :message (lambda (validator object)
              (declare (ignorable validator object))
              (format nil "~A does not match the regex ~S" object (validator-regex validator))))
  (:metaclass closer-mop:funcallable-standard-class))

(defclass url-validator (validator)
  ()
  (:default-initargs
   :message (lambda (validator object)
              (declare (ignorable validator object))
              (format nil "~A is not a valid URL" object)))
  (:metaclass closer-mop:funcallable-standard-class))

(defclass datetime-validator (validator)
  ()
  (:default-initargs
   :message (lambda (validator object)
              (declare (ignorable validator object))
              (format nil "~A is not a valid timestamp" object)))
  (:metaclass closer-mop:funcallable-standard-class))

(defclass pathname-validator (validator)
  ((absolute-p :initarg :absolute-p
               :accessor absolute-p
               :initform nil
               :documentation "If the pathname should be absolute")
   (probe-p :initarg :probe-p
            :accessor probe-p
            :initform nil
            :documentation "Probe existance of pathname")
   (pathname-type :initarg :pathname-type
                  :accessor pathname-type*
                  :initform nil
                  :documentation "The pathname type"))
  (:default-initargs
   :message (lambda (validator object)
              (declare (ignorable validator object))
              (format nil "~A is not a valid pathname" object)))
  (:metaclass closer-mop:funcallable-standard-class))

(defclass not-validator (validator)
  ((validator :initarg :validator
              :accessor validator
              :initform (error "Provide the validator")))
  (:default-initargs
   :message (lambda (validator object)
              (format nil "Not ~A" (validator-message (validator validator) object))))
  (:metaclass closer-mop:funcallable-standard-class))

(defclass and-validator (validator)
  ((x :initarg :x
      :accessor x
      :initform (error "Provide the first validator"))
   (y :initarg :y
      :accessor y
      :initform (error "Provide the second validator")))
  (:default-initargs
   :message (lambda (validator object)
              (if (not (validate (x validator) object :error-p nil))
                  (validator-message (x validator) object)
                  (validator-message (y validator) object))))
  (:metaclass closer-mop:funcallable-standard-class))

(defclass or-validator (validator)
  ((x :initarg :x
      :accessor x
      :initform (error "Provide the first validator"))
   (y :initarg :y
      :accessor y
      :initform (error "Provide the second validator")))
  (:default-initargs
   :message (lambda (validator object)
              (if (validate (x validator) object :error-p nil)
                  (validator-message (x validator) object)
                  (validator-message (y validator) object))))
  (:metaclass closer-mop:funcallable-standard-class))

(defclass one-of-validator (validator)
  ((options :initarg :options
            :accessor options
            :initform (error "Provide the options")))
  (:default-initargs
   :message (lambda (validator object)
              (declare (ignorable validator object))
              (format nil "Should be one of ~{~A~}" (options validator))))
  (:metaclass closer-mop:funcallable-standard-class))

(defclass less-than-validator (validator)
  ((number :initarg :number
           :accessor validator-number
           :initform (error "Provide the number")))
  (:default-initargs
   :message (lambda (validator object)
              (declare (ignorable validator object))
              (format nil "~A is not lower than ~A" object (validator-number validator))))
  (:metaclass closer-mop:funcallable-standard-class))

(defclass greater-than-validator (validator)
  ((number :initarg :number
           :accessor validator-number
           :initform (error "Provide the number")))
  (:default-initargs
   :message (lambda (validator object)
              (declare (ignorable validator object))
              (format nil "~A is not greater than ~A" object (validator-number validator))))
  (:metaclass closer-mop:funcallable-standard-class))

(defclass length-validator (validator)
  ((min :initarg :min
        :accessor validator-min
        :initform nil
        :documentation "Minimum length")
   (max :initarg :max
        :accessor validator-max
        :initform nil
        :documentation "Maximum length")
   (length :initarg :length
           :accessor validator-length
           :initform nil
           :documentation "The expected length")
   (min-message :initarg :min-message
                :accessor validator-min-message
                :initform nil
                :documentation "Message for when length is below minimum")
   (max-message :initarg :max-message
                :accessor validator-max-message
                :initform nil
                :documentation "Message for when length is above maximum"))
  (:default-initargs :message nil)
  (:metaclass closer-mop:funcallable-standard-class))

(defmethod message ((validator length-validator))
  (lambda (validator object)
    (cond
      ((and (validator-length validator)
            (not (= (validator-length validator) (length object))))
       (or (slot-value validator 'message)
           (format nil "~s has not length: ~a" object (validator-length validator))))
      ((and (validator-min validator)
            (< (length object) (validator-min validator)))
       (or (validator-min-message validator)
           (format nil "Length of ~s is less than ~a" object (validator-min validator))))
      ((and (validator-max validator)
            (> (length object) (validator-max validator)))
       (or (validator-max-message validator)
           (format nil "Length of ~s is more than ~a" object (validator-max validator)))))))

(defun validate (validator object &rest args &key (error-p *signal-validation-errors*) message &allow-other-keys)
  "Validate OBJECT with VALIDATOR. Return two values: the status (boolean), an optional message."
  (if (not (apply #'%validate validator object args))
      (let ((message (or message (validator-message validator object))))
        (if error-p
            (validation-error object message)
            (values nil message)))
      (values t nil)))

(defgeneric %validate (validator object &rest args))

(defun validate-all (validators object &rest args &key (error-p *signal-validation-errors*) message &allow-other-keys)
  "Run all validators in turn. Return two values: the status (boolean), and a list of messages."
  (declare (ignorable error-p message args))
  (let ((messages nil)
        (valid t))
    (loop for vdtor in validators
          if (and (eql :allow-blank vdtor)
                  (equal "" (string-trim *whitespaces* object)))
            return t
          else
            do (unless (symbolp vdtor)
                 (multiple-value-bind (status message)
                     (validate vdtor object :error-p error-p)
                   (unless status
                     (setf valid nil))
                   (when message
                     (push message messages)))))
    (values valid
            (reverse (uiop:ensure-list messages)))))

(defmethod %validate ((validator validator-collection) object &rest args)
  (declare (ignorable args))
  (loop for validator in (validators validator)
        do (validate validator object :error-p t)))

(defmethod %validate ((validator equal-to-validator) object &rest args)
  (declare (ignorable args))
  (equalp object (object validator)))

(defmethod %validate ((validator not-equal-to-validator) object &rest args)
  (declare (ignorable args))
  (not (equalp object (object validator))))

(defmethod %validate ((validator type-validator) object &rest args)
  (declare (ignorable args))
  (typep object (validator-type validator)))

(defmethod %validate ((validator function-validator) object &rest args)
  (declare (ignorable args))
  (funcall (validator-function validator) object))

(defmethod %validate ((validator blank-validator) object &rest args)
  (declare (ignorable validator args))
  (or (null object)
      (equalp object "")))

(defmethod %validate ((validator not-blank-validator) object &rest args)
  (declare (ignorable validator args))
  (not (or (null object)
           (equalp object ""))))

(defmethod %validate ((validator true-validator) object &rest args)
  (declare (ignorable validator args))
  (eql t object))

(defmethod %validate ((validator false-validator) object &rest args)
  (declare (ignorable validator args))
  (null object))

(defmethod %validate ((validator length-validator) object &rest args)
  (declare (ignorable args))
  (and (or (null (validator-length validator))
           (= (length object) (validator-length validator)))
       (or (null (validator-min validator))
           (>= (length object) (validator-min validator)))
       (or (null (validator-max validator))
           (<= (length object) (validator-max validator)))))

(defun valid-email-address-p (string)
  (not (null
        (ppcre:scan "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,4}$" string))))

(defmethod %validate ((validator email-validator) object &rest args)
  (declare (ignorable args))
  (valid-email-address-p object))

(defun valid-url-p (string)
  (not (null (ppcre:scan "((([A-Za-z]{3,9}:(?:\\/\\/)?)(?:[\\-;:&=\\+\\$,\\w]+@)?[A-Za-z0-9\\.\\-]+|(?:www\\.|[\\-;:&=\\+\\$,\\w]+@)[A-Za-z0-9\\.\\-]+)((?:\\/[\\+~%\\/\\.\\w\\-_]*)?\\??(?:[\\-\\+=&;%@\\.\\w_]*)#?(?:[\\.\\!\\/\\\\\\w]*))?)" string))))

(defmethod %validate ((validator url-validator) object &rest args)
  (declare (ignorable args))
  (valid-url-p object))

(defmethod %validate ((validator regex-validator) object &rest args)
  (declare (ignorable args))
  (not (null (ppcre:scan (validator-regex validator) object))))

(defmethod %validate ((validator datetime-validator) object &rest args)
  (declare (ignorable args))
  (not (null (chronicity:parse object))))

(defmethod %validate ((validator pathname-validator) object &rest args)
  (declare (ignorable args))
  (and (pathname object)
       (or (not (absolute-p validator))
           (fad:pathname-absolute-p (pathname object)))
       (or (not (pathname-type* validator))
           (equalp (pathname-type (pathname object))
                   (pathname-type* validator)))
       (or (not (probe-p validator))
           (probe-file (pathname object)))))

(defmethod %validate ((validator not-validator) object &rest args)
  (declare (ignorable args))
  (not (%validate (validator validator) object)))

(defmethod %validate ((validator and-validator) object &rest args)
  (declare (ignorable args))
  (and (validate (x validator) object)
       (validate (y validator) object)))

(defmethod %validate ((validator or-validator) object &rest args)
  (if (getf args :signal-validation-errors)
      (handler-case
          (validate (x validator) object)
        (validation-error ()
          (validate (y validator) object)))
      (or (validate (x validator) object)
          (validate (y validator) object))))

(defmethod %validate ((validator one-of-validator) object &rest args)
  (declare (ignorable args))
  (member object (options validator) :test #'equalp))

(defmethod %validate ((validator less-than-validator) object &rest args)
  (declare (ignorable args))
  (< object (validator-number validator)))

(defmethod %validate ((validator greater-than-validator) object &rest args)
  (declare (ignorable args))
  (> object (validator-number validator)))

;; Validator builder functions
(defun == (object &optional message &rest args)
  (declare (ignorable args))
  (apply #'make-instance 'equal-to-validator
         `(:object ,object
                   ,@(when message
                       (list :message (apply #'format nil message args))))))

(defun ~= (object &optional message &rest args)
  (apply #'make-instance 'not-equal-to-validator
         `(:object ,object
                   ,@(when message
                       (list :message (apply #'format nil message args))))))

(defun one-of (options &optional message &rest args)
  (apply #'make-instance 'one-of-validator
         `(:options ,options
                    ,@(when message
                        (list :message (apply #'format nil message args))))))

(defun blank (&optional message &rest args)
  (apply #'make-instance 'blank-validator
         (when message
           (list :message (apply #'format nil message args)))))

(defun not-blank (&optional message &rest args)
  (apply #'make-instance 'not-blank-validator
         (when message
           (list :message (apply #'format nil message args)))))

(defun is-true (&optional message &rest args)
  (apply #'make-instance 'is-true-validator
         (when message
           (list :message (apply #'format nil message args)))))

(defun is-false (&optional message &rest args)
  (apply #'make-instance 'is-false-validator
         (when message
           (list :message (apply #'format nil message args)))))

(defun greater-than (number &optional message &rest args)
  (apply #'make-instance 'greater-than-validator
         `(:number ,number
                   ,@(when message
                       (list :message (apply #'format nil message args))))))

(defun less-than (number &optional message &rest args)
  (apply #'make-instance 'less-than-validator
         `(:number ,number
                   ,@(when message
                       (list :message (apply #'format nil message args))))))

(defun ~ (validator &optional message &rest args)
  (apply #'make-instance 'not-validator
         `(:validator ,validator
                      ,@(when message
                          (list :message (apply #'format nil message args))))))

(defun && (x y &optional message &rest args)
  (apply #'make-instance 'and-validator
         `(:x ,x :y ,y
              ,@(when message
                  (list :message (apply #'format nil message args))))))

;; There's a problem when trying to compile || as function name on ECL
;; So, we don't define it.
#-ecl
(defun || (x y &optional message &rest args)
  (apply #'make-instance 'or-validator
         `(:x ,x :y ,y
              ,@(when message
                  (list :message (apply #'format nil message args))))))

(defun fn (function message &rest args)
  (make-instance 'function-validator
                 :function function
                 :message (apply #'format nil message args)))

(defun is-a (type &optional message &rest args)
  (apply #'make-instance 'type-validator
         `(:type ,type
                 ,@(when message
                     (list :message (apply #'format nil message args))))))

(defun is-a-string (&optional message &rest args)
  (apply #'make-instance 'string-validator
         (when message
           (list :message (apply #'format nil message args)))))

(defun is-a-boolean (&optional message &rest args)
  (apply #'make-instance 'boolean-validator
         (when message
           (list :message (apply #'format nil message args)))))

(defun is-an-integer (&optional message &rest args)
  (apply #'make-instance 'integer-validator
         (when message
           (list :message (apply #'format nil message args)))))

(defun is-a-symbol (&optional message &rest args)
  (apply #'make-instance 'symbol-validator
         (when message
           (list :message (apply #'format nil message args)))))

(defun is-a-keyword (&optional message &rest args)
  (apply #'make-instance 'keyword-validator
         (when message
           (list :message (apply #'format nil message args)))))

(defun is-a-list (&optional message &rest args)
  (apply #'make-instance 'list-validator
         (when message
           (list :message (apply #'format nil message args)))))

(defun valid-email (&optional message &rest args)
  (apply #'make-instance 'email-validator
         (when message
           (list :message (apply #'format nil message args)))))

(defun valid-url (&optional message &rest args)
  (apply #'make-instance 'url-validator
         (when message
           (list :message (apply #'format nil message args)))))

(defun valid-datetime (&optional message &rest args)
  (apply #'make-instance 'datetime-validator
         (when message
           (list :message (apply #'format nil message args)))))

(defun valid-pathname (&optional message &rest args)
  (apply #'make-instance 'pathname-validator
         (when message
           (list :message (apply #'format nil message args)))))

(defun matches-regex (regex &optional message &rest args)
  (apply #'make-instance 'regex-validator
         `(:regex ,regex
                  ,@(when message
                      (list :message (apply #'format nil message args))))))

(defun len (&key min max message min-message max-message)
  (apply #'make-instance 'length-validator
         :min min
         :max max
         (alexandria:flatten
          (remove-if #'null
                     (list
                      (when message
                        (list :message message))
                      (when min-message
                        (list :min-message min-message))
                      (when max-message
                        (list :max-message max-message)))))))

(defun validator-message (validator object)
  "Returns the validator message for the given object"
  (if (stringp (message validator))
      (message validator)
      (funcall (message validator)
               validator
               object)))
