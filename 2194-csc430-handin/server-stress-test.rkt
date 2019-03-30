#lang racket

(require 2192-csc430-handin/client
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

  (define u (make-object text%))

  (editors->string (list t u)))


(define submit-dir "Program5")
(define grading-dir
  "/tmp"
  #;(build-path "/Users/clements/430/Grading/Program4/shuffled-16"))
(define encoded-bytes
  (file->encoded-string
   #;(build-path grading-dir "handin-text.rkt")
   "/Users/clements/430/Solutions/Program5/a5-tr-singlefile-solution.rkt"))

(define (copy-test-log-out)
  (copy-file
   (build-path "/tmp/handin-tmp" submit-dir "clements" "test-log.txt")
   (build-path grading-dir "test-log.txt")
   #t))

;; given a unique
(define (run-submit)
  (define handin (handin-connect host port))
  (define channel (make-async-channel))
  (define t (current-inexact-milliseconds))
  (define (time-taken)
    (inexact->exact
     (ceiling (- (current-inexact-milliseconds) t))))
  (define (mk-cbk label)
    (λ args (async-channel-put
             channel
             (cons label (cons (time-taken) args)))))
  (define result
    (with-handlers
        ([exn:fail? (λ (exn)
                      (list 'exn
                            (time-taken)
                            (exn-message exn)))])  
      (submit-assignment handin
                         uid
                         password
                         submit-dir
                         encoded-bytes
                         (mk-cbk 'success)
                         (mk-cbk 'message)
                         (mk-cbk 'message-final)
                         (mk-cbk 'message-box))
      'success))
  
  ;; drain all messages from the async-channel:
  (define messages
    (let loop ()
      (define n (async-channel-try-get channel))
      (cond [n (cons n (loop))]
            [else '()])))
  ;; really nothing to do with stress testing...,.
  #;(copy-test-log-out)
  (list result (time-taken) messages))

(define delay 0.0)
(define results (make-async-channel))
(for/list ([i (in-range 5)]
           [t (in-naturals)])
  (thread
   (λ () (begin
           (sleep (* t delay))
           (async-channel-put results
                              (list (list 'sleep (* t delay))
                                    (run-submit)))))))

(let loop ()
  (define r (async-channel-get results))
  (pretty-print r)
  (loop))