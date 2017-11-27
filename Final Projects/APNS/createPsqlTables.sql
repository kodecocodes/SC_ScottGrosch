CREATE TABLE info (
    ident uuid NOT NULL,
    app character varying NOT NULL,
    languages character varying NOT NULL,
    ios character varying NOT NULL,
    created timestamp(0) with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY info ADD CONSTRAINT info_pkey PRIMARY KEY (ident, app);

CREATE TABLE apns (
    token character varying NOT NULL PRIMARY KEY,
    created timestamp(0) with time zone DEFAULT now() NOT NULL
);

