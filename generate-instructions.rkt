#lang at-exp racket

(require racket/runtime-path)

(define-runtime-path here ".")
(define prev-qtr 2262)
(define this-qtr 2264)
(define course-num 430)
(define subject "csc")

;; might not work for some courses duh
(define course-id (~a subject course-num))

(define prev-handin-dir (build-path "~/" (~a prev-qtr "-" course-num "-handin")))

(define existing-subdir-name (~a prev-qtr "-" course-id "-handin"))
(define new-subdir-name      (~a  this-qtr "-" course-id "-handin"))

(define content
  @list{

There's a tag for each class.

1) Check certificate expiration with

openssl x509 -text < @|prev-handin-dir|/server-cert.pem 

If necessary, regen cert with

```
cd @here`
openssl req -new -nodes -x509 -years 5 -out server-cert.pem -keyout private-key.pem
mv private-key.pem ~/@|course-num|/Handin/
cp server-cert.pem ~/@|this-qtr|-@|course-num|-handin
```

2) git mv directory to new collection name


cd @here && git mv @|existing-subdir-name| @|new-subdir-name|

3) update inner info.rkt

```
dopen @|here|/@|new-subdir-name|/info.rkt
```

4) first push to master

```
cd @here
git add .
git commit -m "updates for @|this-qtr|"
git push
```

7) finally, tag the commit and push

```
cd @here
git tag -m "@|this-qtr| handin client" @|this-qtr|-@|course-id|
git push origin @|this-qtr|-@|course-id|
```

NB. The tag name here appears in the Lab 0 directions, so it has to be of the form <qtr>-<course>
})

(for-each display content)
