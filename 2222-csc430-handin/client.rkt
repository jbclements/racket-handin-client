#lang racket/base

(require racket/contract openssl/mzssl "this-collection.rkt")

(provide
 (contract-out
  [handin-connect (-> string? (integer-in 1 65535) handin?)]
  [handin-disconnect! (-> handin? void?)]
  [retrieve-user-fields (-> handin? (listof string?))]
  [retrieve-active-assignments (-> handin? (listof string?))]
  [submit-assignment (-> handin? string? string? string? bytes?
                         (-> any)
                         (-> any/c any) (-> any/c any) (-> any/c any/c any)
                         void?)]
  [retrieve-assignment (-> handin? string? string? string? bytes?)]
  [submit-addition (-> handin? string? string? (listof string?) void?)]
  [submit-info-change (-> handin? string? string? string? (listof string?) void?)]
  [retrieve-user-info (-> handin? string? string? (listof string?))]))

;; represents a handin connection, containing two ports
(define-struct handin (r w))

;; errors to the user: no need for a "foo: " prefix
(define (error* fmt . args)
  (error (apply format fmt args)))

(define (write+flush port . xs)
  (for ([x (in-list xs)]) (write x port) (newline port))
  (flush-output port))

;; close both ports associated with a handin, return void
(define (close-handin-ports! h)
  (close-input-port (handin-r h))
  (close-output-port (handin-w h)))

;; given a value, ensure that it is 'ok.
(define (ensure-ok v who)
  (unless (eq? v 'ok) (error* "~a error: ~a" who v)))

;; create a handin connection to the given server and port
(define (handin-connect server port)
  (let-values ([(r w) (connect-to server port)])
    (write+flush w 'handin)
    ;; Sanity check: server sends "handin", first:
    (let ([s (read-bytes 6 r)])
      (unless (equal? #"handin" s)
        (error 'handin-connect "bad handshake from server: ~e" s)))
    ;; Tell server protocol = 'ver1:
    (write+flush w 'ver1)
    ;; One more sanity check: server recognizes protocol:
    (let ([s (read r)])
      (unless (eq? s 'ver1)
        (error 'handin-connect "bad protocol from server: ~e" s)))
    ;; Return connection:
    (make-handin r w)))

;; ssl connection, makes a readable error message if no connection
;; given a server and a port, returns an input and output port
(define (connect-to server port)
  (define pem (in-this-collection "server-cert.pem"))
  (define ctx (ssl-make-client-context))
  (ssl-set-verify! ctx #t)
  (ssl-load-verify-root-certificates! ctx pem)
  (with-handlers
      ([exn:fail:network?
        (lambda (e)
          (let* ([msg
                  "handin-connect: could not connect to the server (~a:~a)"]
                 [msg (format msg server port)]
                 #; ; un-comment to get the full message too
                 [msg (string-append msg " (" (exn-message e) ")")])
            (raise (make-exn:fail:network msg (exn-continuation-marks e)))))])
    (ssl-connect server port ctx)))

;; disconnect a handin connection
(define (handin-disconnect! h)
  (write+flush (handin-w h) 'bye)
  (close-handin-ports! h))

;; given a handin connection, retrieve a list of
;; strings representing the user fields, then
;; close the handin connection
(define (retrieve-user-fields h)
  (let ([r (handin-r h)] [w (handin-w h)])
    (write+flush w 'get-user-fields 'bye)
    (let ([v (read r)])
      (unless (and (list? v) (andmap string? v))
        (error* "failed to get user-fields list from server"))
      (ensure-ok (read r) "get-user-fields")
      (close-handin-ports! h)
      v)))

;; given a handin connection, retrieve a list
;; of strings representing the active assignments
(define (retrieve-active-assignments h)
  (let ([r (handin-r h)] [w (handin-w h)])
    (write+flush w 'get-active-assignments)
    (let ([v (read r)])
      (unless (and (list? v) (andmap string? v))
        (error* "failed to get active-assignment list from server"))
      v)))

;; given a handin connection, a username, a password, an assignment name,
;; the buffer content bytes, a thunk to be called on success, a message
;; display handler, a message-final display handler, and a message-box
;; display handler, submit the assignment and close the handin connection
(define (submit-assignment h username passwd assignment content
                           on-commit message message-final message-box)
  (let ([r (handin-r h)] [w (handin-w h)])
    ;; a mini-event loop, handling messages from the current-input-port
    ;; until we get one that's not a message (in which case it's returned).
    (define (read/message)
      (let ([v (read r)])
        ;; invoke the appropriate handler (or return if it's not a message)
        (case v
          [(message) (message (read r)) (read/message)]
          [(message-final) (message-final (read r)) (read/message)]
          [(message-box)
           (write+flush w (message-box (read r) (read r))) (read/message)]
          [else v])))
    (write+flush w
      'set 'username/s username
      'set 'password   passwd
      'set 'assignment assignment
      'save-submission)
    (ensure-ok (read r) "login")
    (write+flush w (bytes-length content))
    (let ([v (read r)])
      (unless (eq? v 'go) (error* "upload error: ~a" v)))
    (display "$" w)
    (display content w)
    (flush-output w)
    ;; during processing, we're waiting for 'confirm, in the meanwhile, we
    ;; can get a 'message or 'message-box to show -- after 'message we expect
    ;; a string to show using the `message' argument, and after 'message-box
    ;; we expect a string and a style-list to be used with `message-box' and
    ;; the resulting value written back
    (let ([v (read/message)])
      (unless (eq? 'confirm v) (error* "submit error: ~a" v)))
    (on-commit)
    (write+flush w 'check)
    (ensure-ok (read/message) "commit")
    (close-handin-ports! h)))

;; given a handin connection, a username, a password, and an assignment name,
;; return a byte string containing the retrieved assignment and close the
;; handin connection.
(define (retrieve-assignment h username passwd assignment)
  (let ([r (handin-r h)] [w (handin-w h)])
    (write+flush w
      'set 'username/s username
      'set 'password   passwd
      'set 'assignment assignment
      'get-submission)
    (let ([len (read r)])
      (unless (and (number? len) (integer? len) (positive? len))
        (error* "bad response from server: ~a" len))
      (let ([buf (begin (regexp-match #rx"[$]" r) (read-bytes len r))])
        (ensure-ok (read r) "get-submission")
        (close-handin-ports! h)
        buf))))

;; given a handin connection, a username, a password, and user fields,
;; create the user and close the handin connection.
(define (submit-addition h username passwd user-fields)
  (let ([r (handin-r h)] [w (handin-w h)])
    (write+flush w
      'set 'username/s  username
      'set 'password    passwd
      'set 'user-fields user-fields
      'create-user)
    (ensure-ok (read r) "create-user")
    (close-handin-ports! h)))

;; given a handin connection, a username, an old password, a new password,
;; and user fields, update the user's information and close the handin
;; connection
(define (submit-info-change h username old-passwd new-passwd user-fields)
  (let ([r (handin-r h)]
        [w (handin-w h)])
    (write+flush w
      'set 'username/s   username
      'set 'password     old-passwd
      'set 'new-password new-passwd
      'set 'user-fields  user-fields
      'change-user-info)
    (ensure-ok (read r) "change-user-info")
    (close-handin-ports! h)))

;; given a handin connection, a username, and a password, return a list
;; of strings representing the user's info and close the handin connection.
(define (retrieve-user-info h username passwd)
  (let ([r (handin-r h)] [w (handin-w h)])
    (write+flush w
      'set 'username/s username
      'set 'password   passwd
      'get-user-info 'bye)
    (let ([v (read r)])
      (unless (and (list? v) (andmap string? v))
        (error* "failed to get user-info list from server"))
      (ensure-ok (read r) "get-user-info")
      (close-handin-ports! h)
      v)))
