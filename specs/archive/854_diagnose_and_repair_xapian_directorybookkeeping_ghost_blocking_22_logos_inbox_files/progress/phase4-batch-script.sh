echo '--- UID 145 ---'
docid=$(xapian-delve -t 'XFDIRENTRY69358:1783354873.4003086_145.hamsa,U=145:2,' /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '[0-9]+$')
echo "docid=$docid"
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '(^| )K[a-z-]+' | tr -d ' '
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE 'PLogos/cur( |$)' | head -1
echo '--- UID 159 ---'
docid=$(xapian-delve -t 'XFDIRENTRY69358:1783354873.4003086_159.hamsa,U=159:2,' /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '[0-9]+$')
echo "docid=$docid"
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '(^| )K[a-z-]+' | tr -d ' '
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE 'PLogos/cur( |$)' | head -1
echo '--- UID 163 ---'
docid=$(xapian-delve -t 'XFDIRENTRY69358:1783354873.4003086_163.hamsa,U=163:2,' /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '[0-9]+$')
echo "docid=$docid"
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '(^| )K[a-z-]+' | tr -d ' '
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE 'PLogos/cur( |$)' | head -1
echo '--- UID 189 ---'
docid=$(xapian-delve -t 'XFDIRENTRY69358:1783354874.4003086_189.hamsa,U=189:2,' /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '[0-9]+$')
echo "docid=$docid"
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '(^| )K[a-z-]+' | tr -d ' '
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE 'PLogos/cur( |$)' | head -1
echo '--- UID 200 ---'
docid=$(xapian-delve -t 'XFDIRENTRY69358:1783354874.4003086_200.hamsa,U=200:2,' /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '[0-9]+$')
echo "docid=$docid"
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '(^| )K[a-z-]+' | tr -d ' '
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE 'PLogos/cur( |$)' | head -1
echo '--- UID 212 ---'
docid=$(xapian-delve -t 'XFDIRENTRY69358:1783354874.4003086_212.hamsa,U=212:2,' /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '[0-9]+$')
echo "docid=$docid"
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '(^| )K[a-z-]+' | tr -d ' '
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE 'PLogos/cur( |$)' | head -1
echo '--- UID 213 ---'
docid=$(xapian-delve -t 'XFDIRENTRY69358:1783354874.4003086_213.hamsa,U=213:2,' /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '[0-9]+$')
echo "docid=$docid"
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '(^| )K[a-z-]+' | tr -d ' '
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE 'PLogos/cur( |$)' | head -1
echo '--- UID 214 ---'
docid=$(xapian-delve -t 'XFDIRENTRY69358:1783354874.4003086_214.hamsa,U=214:2,' /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '[0-9]+$')
echo "docid=$docid"
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '(^| )K[a-z-]+' | tr -d ' '
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE 'PLogos/cur( |$)' | head -1
echo '--- UID 215 ---'
docid=$(xapian-delve -t 'XFDIRENTRY69358:1783354874.4003086_215.hamsa,U=215:2,' /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '[0-9]+$')
echo "docid=$docid"
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '(^| )K[a-z-]+' | tr -d ' '
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE 'PLogos/cur( |$)' | head -1
echo '--- UID 256 ---'
docid=$(xapian-delve -t 'XFDIRENTRY69358:1783354874.4003086_256.hamsa,U=256:2,' /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '[0-9]+$')
echo "docid=$docid"
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '(^| )K[a-z-]+' | tr -d ' '
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE 'PLogos/cur( |$)' | head -1
echo '--- UID 258 ---'
docid=$(xapian-delve -t 'XFDIRENTRY69358:1783354874.4003086_258.hamsa,U=258:2,' /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '[0-9]+$')
echo "docid=$docid"
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '(^| )K[a-z-]+' | tr -d ' '
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE 'PLogos/cur( |$)' | head -1
echo '--- UID 266 ---'
docid=$(xapian-delve -t 'XFDIRENTRY69358:1783354874.4003086_266.hamsa,U=266:2,' /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '[0-9]+$')
echo "docid=$docid"
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '(^| )K[a-z-]+' | tr -d ' '
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE 'PLogos/cur( |$)' | head -1
echo '--- UID 271 ---'
docid=$(xapian-delve -t 'XFDIRENTRY69358:1783354874.4003086_271.hamsa,U=271:2,' /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '[0-9]+$')
echo "docid=$docid"
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '(^| )K[a-z-]+' | tr -d ' '
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE 'PLogos/cur( |$)' | head -1
echo '--- UID 274 ---'
docid=$(xapian-delve -t 'XFDIRENTRY69358:1783354874.4003086_274.hamsa,U=274:2,' /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '[0-9]+$')
echo "docid=$docid"
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '(^| )K[a-z-]+' | tr -d ' '
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE 'PLogos/cur( |$)' | head -1
echo '--- UID 277 ---'
docid=$(xapian-delve -t 'XFDIRENTRY69358:1783354874.4003086_277.hamsa,U=277:2,' /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '[0-9]+$')
echo "docid=$docid"
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '(^| )K[a-z-]+' | tr -d ' '
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE 'PLogos/cur( |$)' | head -1
echo '--- UID 279 ---'
docid=$(xapian-delve -t 'XFDIRENTRY69358:1783354874.4003086_279.hamsa,U=279:2,' /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '[0-9]+$')
echo "docid=$docid"
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '(^| )K[a-z-]+' | tr -d ' '
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE 'PLogos/cur( |$)' | head -1
echo '--- UID 280 ---'
docid=$(xapian-delve -t 'XFDIRENTRY69358:1783354874.4003086_280.hamsa,U=280:2,' /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '[0-9]+$')
echo "docid=$docid"
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '(^| )K[a-z-]+' | tr -d ' '
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE 'PLogos/cur( |$)' | head -1
echo '--- UID 282 ---'
docid=$(xapian-delve -t 'XFDIRENTRY69358:1783354874.4003086_282.hamsa,U=282:2,' /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '[0-9]+$')
echo "docid=$docid"
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '(^| )K[a-z-]+' | tr -d ' '
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE 'PLogos/cur( |$)' | head -1
echo '--- UID 287 ---'
docid=$(xapian-delve -t 'XFDIRENTRY69358:1783354874.4003086_287.hamsa,U=287:2,' /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '[0-9]+$')
echo "docid=$docid"
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '(^| )K[a-z-]+' | tr -d ' '
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE 'PLogos/cur( |$)' | head -1
echo '--- UID 295 ---'
docid=$(xapian-delve -t 'XFDIRENTRY69358:1783354874.4003086_295.hamsa,U=295:2,' /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '[0-9]+$')
echo "docid=$docid"
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '(^| )K[a-z-]+' | tr -d ' '
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE 'PLogos/cur( |$)' | head -1
echo '--- UID 300 ---'
docid=$(xapian-delve -t 'XFDIRENTRY69358:1783354874.4003086_300.hamsa,U=300:2,' /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '[0-9]+$')
echo "docid=$docid"
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '(^| )K[a-z-]+' | tr -d ' '
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE 'PLogos/cur( |$)' | head -1
echo '--- UID 305 ---'
docid=$(xapian-delve -t 'XFDIRENTRY69358:1783354874.4003086_305.hamsa,U=305:2,' /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '[0-9]+$')
echo "docid=$docid"
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE '(^| )K[a-z-]+' | tr -d ' '
xapian-delve -r "$docid" /home/benjamin/Mail/.notmuch/xapian/ 2>&1 | grep -oE 'PLogos/cur( |$)' | head -1
