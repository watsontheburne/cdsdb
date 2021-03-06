PRAGMA synchronous=0;
PRAGMA encoding="UTF-8";

BEGIN TRANSACTION;

CREATE TABLE "dbversion"
(
    "sversion" VARCHAR NOT NULL DEFAULT '7.1'
);

CREATE TABLE "origins"
(
  "rorigin" INTEGER PRIMARY KEY DEFAULT 0 NOT NULL,
  "sname"   VARCHAR NOT NULL DEFAULT '',
  "scode"   VARCHAR NOT NULL DEFAULT ''
);

CREATE TABLE "artists"
(
  "rartist"  INTEGER PRIMARY KEY DEFAULT 0 NOT NULL,
  "sname"    VARCHAR NOT NULL DEFAULT '',
  "swebsite" VARCHAR NOT NULL DEFAULT '',
  "rorigin"  INTEGER NOT NULL DEFAULT 0 REFERENCES origins(rorigin),
  "mnotes"   VARCHAR NOT NULL DEFAULT ''
);

CREATE TABLE "collections"
(
  "rcollection"	INTEGER PRIMARY KEY DEFAULT 0 NOT NULL,
  "sname"	VARCHAR NOT NULL DEFAULT ''
);

CREATE TABLE "segments"
(
  "rsegment"    INTEGER PRIMARY KEY DEFAULT 0 NOT NULL,
  "rrecord"     INTEGER NOT NULL DEFAULT 0 REFERENCES records(rrecord),
  "rartist"     INTEGER NOT NULL DEFAULT 0 REFERENCES artists(rartist),
  "iorder"      SMALLINT NOT NULL DEFAULT 0,
  "stitle"      VARCHAR NOT NULL DEFAULT '',
  "iplaytime"   INTEGER NOT NULL DEFAULT 0,
  "mnotes"      VARCHAR NOT NULL DEFAULT ''
);

CREATE TABLE "labels"
(
  "rlabel" INTEGER PRIMARY KEY DEFAULT 0 NOT NULL,
  "sname"  VARCHAR NOT NULL DEFAULT ''
);

CREATE TABLE "medias"
(
  "rmedia" INTEGER PRIMARY KEY DEFAULT 0 NOT NULL,
  "sname"  VARCHAR NOT NULL DEFAULT ''
);

CREATE TABLE "genres"
(
  "rgenre" INTEGER PRIMARY KEY DEFAULT 0 NOT NULL,
  "sname"  VARCHAR NOT NULL DEFAULT ''
);

CREATE TABLE "records"
(
  "rrecord"         INTEGER PRIMARY KEY DEFAULT 0 NOT NULL,
  "icddbid"         INTEGER NOT NULL DEFAULT 0,
  "rartist"         INTEGER NOT NULL DEFAULT 0 REFERENCES artists(rartist),
  "stitle"          VARCHAR NOT NULL DEFAULT '',
  "iyear"           SMALLINT NOT NULL DEFAULT 0,
  "rlabel"          INTEGER NOT NULL DEFAULT 0 REFERENCES labels(rlabel),
  "rgenre"          INTEGER NOT NULL DEFAULT 0 REFERENCES genres(rgenre),
  "rmedia"          INTEGER NOT NULL DEFAULT 0 REFERENCES medias(rmedia),
  "rcollection"     INTEGER NOT NULL DEFAULT 0 REFERENCES collections(rcollection),
  "iplaytime"       INTEGER NOT NULL DEFAULT 0,
  "isetorder"       SMALLINT NOT NULL DEFAULT 0,
  "isetof"          SMALLINT NOT NULL DEFAULT 0,
  "scatalog"        VARCHAR NOT NULL DEFAULT '',
  "mnotes"          VARCHAR NOT NULL DEFAULT '',
  "idateadded"      INTEGER NOT NULL DEFAULT 0,
  "idateripped"     INTEGER NOT NULL DEFAULT 0,
  "iissegmented"    SMALLINT NOT NULL DEFAULT 0,
  "irecsymlink"     INTEGER NOT NULL DEFAULT 0,
  "ipeak"           INTEGER NOT NULL DEFAULT 0,
  "igain"           INTEGER NOT NULL DEFAULT 0,
  "itrackscount"    INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE "tracks"
(
  "rtrack"      INTEGER PRIMARY KEY DEFAULT 0 NOT NULL,
  "rsegment"    INTEGER NOT NULL DEFAULT 0 REFERENCES segments(rsegment),
  "rrecord"     INTEGER NOT NULL DEFAULT 0 REFERENCES records(rrecord),
  "iorder"      SMALLINT NOT NULL DEFAULT 0,
  "iplaytime"   INTEGER NOT NULL DEFAULT 0,
  "stitle"      VARCHAR NOT NULL DEFAULT '',
  "mnotes"      VARCHAR NOT NULL DEFAULT '',
  "isegorder"   INTEGER NOT NULL DEFAULT 0,
  "iplayed"     INTEGER NOT NULL DEFAULT 0,
  "irating"     INTEGER NOT NULL DEFAULT 0,
  "itags"       INTEGER NOT NULL DEFAULT 0,
  "ilastplayed" INTEGER NOT NULL DEFAULT 0,
  "ipeak"       INTEGER NOT NULL DEFAULT 0,
  "igain"       INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE "plists" (
    "rplist"        INTEGER PRIMARY KEY DEFAULT 0 NOT NULL,
    "sname"         VARCHAR NOT NULL DEFAULT 'New play list',
    "iislocal"      INTEGER NOT NULL DEFAULT 0,
    "idatecreated"  INTEGER NOT NULL DEFAULT 0,
    "idatemodified" INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE "pltracks" (
    "rpltrack" INTEGER PRIMARY KEY DEFAULT 0 NOT NULL,
    "rplist"   INTEGER NOT NULL DEFAULT 0 REFERENCES plists(rplist),
    "rtrack"   INTEGER NOT NULL DEFAULT 0 REFERENCES tracks(rtrack),
    "iorder"   INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE "hosts" (
    "rhost"     INTEGER PRIMARY KEY DEFAULT 0 NOT NULL,
    "sname"     VARCHAR NOT NULL DEFAULT 'localhost'
);

CREATE TABLE "logtracks" (
    "rtrack"        INTEGER NOT NULL DEFAULT 0 REFERENCES tracks(rtrack),
    "idateplayed"   INTEGER NOT NULL DEFAULT 0,
    "rhost"         INTEGER NOT NULL DEFAULT 0 REFERENCES hosts(rhost)
);

CREATE TABLE "filters" (
    "rfilter"   INTEGER NOT NULL DEFAULT 0,
    "sname"     VARCHAR NOT NULL DEFAULT 'New filter',
    "sjsondata" VARCHAR NOT NULL DEFAULT ''
);

CREATE INDEX "ixartistname" ON "artists"("sname");
CREATE INDEX "ixrecordtitle" ON "records"("stitle");
/*
CREATE INDEX "ixlogrtrack" ON "logtracks"("rtrack");
CREATE INDEX "ixlogdplayed" ON "logtracks"("idateplayed");
*/

INSERT INTO "dbversion" VALUES ('7.1');

INSERT INTO "origins" VALUES ( 0, 'Unknown', '_united_nations');
INSERT INTO "origins" VALUES ( 1, 'Deutschland', 'de');
INSERT INTO "origins" VALUES ( 2, 'Italia', 'it');
INSERT INTO "origins" VALUES ( 3, 'Australia', 'au');
INSERT INTO "origins" VALUES ( 4, 'Sverige', 'se');
INSERT INTO "origins" VALUES ( 5, 'Svizra', 'ch');
INSERT INTO "origins" VALUES ( 6, 'Norge', 'no');
INSERT INTO "origins" VALUES ( 7, 'U.K.', 'gb');
INSERT INTO "origins" VALUES ( 8, 'U.S.A.', 'us');
INSERT INTO "origins" VALUES ( 9, 'Canada', 'ca');
INSERT INTO "origins" VALUES (10, 'Belgique', 'be');
INSERT INTO "origins" VALUES (11, 'France', 'fr');
INSERT INTO "origins" VALUES (12, 'Euskal Herria', '_basque');
INSERT INTO "origins" VALUES (13, 'Neederland', 'nl');
INSERT INTO "origins" VALUES (14, 'Suomen', 'fi');
INSERT INTO "origins" VALUES (15, 'España', 'es');
INSERT INTO "origins" VALUES (16, 'Brasil', 'br');
INSERT INTO "origins" VALUES (17, 'Österreich', 'at');
INSERT INTO "origins" VALUES (18, 'Danmark', 'dk');
INSERT INTO "origins" VALUES (19, 'Magyar', 'hu');
INSERT INTO "origins" VALUES (20, 'Россия', 'ru');
INSERT INTO "origins" VALUES (21, 'Česko', 'cz');
INSERT INTO "origins" VALUES (22, 'Japan', 'jp');
INSERT INTO "origins" VALUES (23, 'Ireland', 'ie');
INSERT INTO "origins" VALUES (24, 'Ísland', 'is');
INSERT INTO "origins" VALUES (25, '대한민국', 'kr');
INSERT INTO "origins" VALUES (26, 'New Zealand', 'nz');
INSERT INTO "origins" VALUES (27, 'Hellás', 'gr');
INSERT INTO "origins" VALUES (28, 'Føroyar', 'fo');
INSERT INTO "origins" VALUES (29, 'Colombia', 'co');
INSERT INTO "origins" VALUES (30, 'Scotland', '_scotland');
INSERT INTO "origins" VALUES (31, 'Portugal', 'pt');
INSERT INTO "origins" VALUES (32, 'Luxembourg', 'lu');
INSERT INTO "origins" VALUES (33, 'Eesti Vabariik', 'ee');
INSERT INTO "origins" VALUES (34, 'South Africa', 'za');
INSERT INTO "origins" VALUES (35, 'México', 'mx');

COMMIT;
