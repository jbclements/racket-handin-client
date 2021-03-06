racket-handin-client
====================

The plugin to allow handin in csc430. Note: this repo does not need to be
private, because no secrets are stored in it.

There's a tag for each class.

1) cd $HANDIN_DIR

2) Check certificate expiration with

openssl x509 -text < server-cert.pem 

If necessary, regen cert with

- `openssl req -new -nodes -x509 -days 365 -out server-cert.pem -keyout private-key.pem`
- `mv private-key.pem ~/430/handin`
- `cp server-cert.pem ~/430/handin`

3) git mv directory to new collection name

4) update inner info.rkt

5) first push to master

```
git push
```

6) finally, use git tag -m "message" <name-of-tag> to tag the commit, then push.

E.G.

```
git tag -m "2194 handin client" 2194-csc430
git push origin 2194-csc430
```

NB. The tag name here appears in the Lab 0 directions, so it has to be of the form <qtr>-<course>

