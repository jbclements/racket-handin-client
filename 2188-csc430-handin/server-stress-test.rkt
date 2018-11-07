#lang racket

(require "client.rkt"
         racket/gui/base
         racket/async-channel
         racket/runtime-path)

(define-runtime-path here ".")

(define login-info
  (file->value
    (build-path here "private-login-info.rktd")))
(define uid (dict-ref login-info 'uid))
(define password (dict-ref login-info 'password))
(define host (dict-ref login-info 'host))
(define port (dict-ref login-info 'port))

;(handin-disconnect! handin)
;(handin-disconnect! handin)

(define (editors->string editors)
  (let* ([base (make-object editor-stream-out-bytes-base%)]
         [stream (make-object editor-stream-out% base)])
    (write-editor-version stream base)
    (write-editor-global-header stream)
    (for ([ed (in-list editors)]) (send ed write-to-file stream))
    (write-editor-global-footer stream)
    (send base get-bytes)))

;; given a file path, read it into a text%, then convert it to
;; the wxme equivalent for use with submit-assignment:
(define (file->encoded-string f)
  (define t (make-object text%))

  (send t load-file f)

  (editors->string (list t)))


(define encoded-bytes
  (file->encoded-string
   "/Users/clements/430/Solutions/Program4/a4-tr-onefile-solution.rkt"))

;; given a unique
(define (run-submit)
  (define handin (handin-connect host port))
  (define channel (make-async-channel))
  (define (mk-cbk label)
    (λ args (async-channel-put channel (cons label args))))
  (define t (current-inexact-milliseconds))
  (with-handlers
      ([exn:fail? (λ (exn)
                    (list 'exn
                          (- (current-inexact-milliseconds) t)
                          (exn-message exn)))])  
    (submit-assignment handin
                       uid
                       password
                       "Program4"
                       encoded-bytes
                       (mk-cbk 'success)
                       (mk-cbk 'message)
                       (mk-cbk 'message-final)
                       (mk-cbk 'message-box))
    (define time (- (current-inexact-milliseconds) t))
    ;; drain all messages from the async-channel:
    (define messages
      (let loop ()
        (define n (async-channel-try-get channel))
        (cond [n (cons n (loop))]
              [else '()])))
    (list 'success time messages)))

(define results (make-async-channel))
(for/list ([i (in-range 4)])
  (sleep 1)
  (thread
   (λ () (async-channel-put results
                            (run-submit)))))

(let loop ()
  (define r (async-channel-get results))
  (pretty-print r)
  (loop))