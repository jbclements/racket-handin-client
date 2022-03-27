racket-handin-client
====================

The plugin to allow handin in csc430. Note: this repo does not need to be
private, because no secrets are stored in it.

export RHC=`pwd`

There's a tag for each class.

1) cd ~/<this-qtr>-430-handin/

2) Check certificate expiration with

openssl x509 -text < server-cert.pem 

If necessary, regen cert with

- `cd $RHC`
- `openssl req -new -nodes -x509 -days 365 -out server-cert.pem -keyout private-key.pem`
- `mv private-key.pem ~/430/handin`
- `cp server-cert.pem $THISREPO/<the-only-subdirectory>`


3) git mv directory to new collection name

- `cd $RHC`
- git mv 2222-csc430-handin 2224-csc430-handin

4) update inner info.rkt

5) first push to master

```
git add .
git commit -m "updates for 2224"
git push
```

6) finally, use git tag -m "message" <name-of-tag> to tag the commit, then push.

E.G.

```
git tag -m "2194 handin client" 2194-csc430
git push origin 2194-csc430
```

NB. The tag name here appears in the Lab 0 directions, so it has to be of the form <qtr>-<course>

