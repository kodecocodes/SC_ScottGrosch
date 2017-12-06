CREATE USER apns CREATEDB PASSWORD 'apns';
CREATE DATABASE apns OWNER = apns;

\connect apns

CREATE TABLE info (
    ident uuid NOT NULL,
    app character varying NOT NULL,
    languages character varying NOT NULL,
    ios character varying NOT NULL,
    created timestamp(0) with time zone DEFAULT now() NOT NULL
);

ALTER TABLE info ADD CONSTRAINT info_pkey PRIMARY KEY (ident, app);
ALTER TABLE info OWNER TO apns;

CREATE TABLE apns (
    token character varying NOT NULL PRIMARY KEY,
    created timestamp(0) with time zone DEFAULT now() NOT NULL
);

ALTER TABLE apns OWNER TO apns;
