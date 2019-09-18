racket-handin-client
====================

The plugin to allow handin in csc430. Note: this repo does not need to be
private, because no secrets are stored in it.

There's a tag for each class.

1) Check certificate expiration with

openssl x509 -text < server-cert.pem 

2) move directory to new collection name

3) update inner info.rkt

4) first push to master

```
git push
```

5) finally, use git tag -m "message" <name-of-tag> to tag the commit, then push.

E.G.

```
git tag -m "2194 handin client" 2194-csc430
git push origin 2194-csc430
```

