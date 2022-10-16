BEGIN TRANSACTION;
CREATE TABLE IF NOT EXISTS "cheats" (
	"id"	INTEGER NOT NULL,
	"command_id"	INTEGER NOT NULL,
	"description"	TEXT NOT NULL,
	"template"	TEXT NOT NULL,
	FOREIGN KEY("command_id") REFERENCES "commands"("id"),
	PRIMARY KEY("id" AUTOINCREMENT)
);
CREATE TABLE IF NOT EXISTS "clu_metadata" (
	"key"	TEXT NOT NULL,
	"value"	TEXT NOT NULL,
	PRIMARY KEY("key")
);
CREATE TABLE IF NOT EXISTS "commands" (
	"id"	INTEGER NOT NULL,
	"name"	TEXT NOT NULL UNIQUE,
	"description"	TEXT,
	"usage_command"	TEXT,
	"fallback_usage"	TEXT,
	"location"	TEXT,
	"type"	TEXT,
	"language"	TEXT,
	"source_url"	TEXT,
	"source_repo_url"	TEXT,
	"asciicast_url"	TEXT,
	PRIMARY KEY("id" AUTOINCREMENT)
);
CREATE TABLE IF NOT EXISTS "tags" (
	"id"	INTEGER NOT NULL,
	"tag"	TEXT NOT NULL UNIQUE,
	PRIMARY KEY("id" AUTOINCREMENT)
);
CREATE TABLE IF NOT EXISTS "commands_tags" (
	"command_id"	INTEGER NOT NULL,
	"tag_id"	INTEGER NOT NULL,
	PRIMARY KEY("tag_id","command_id")
);
CREATE VIRTUAL TABLE commands_fts USING fts5(
	id,
	name,
	description,
	language,
	tags,
	content=commands,
	content_rowid=id,
	tokenize=porter
);
CREATE TABLE IF NOT EXISTS "commands_fts_data" (
	"id"	INTEGER,
	"block"	BLOB,
	PRIMARY KEY("id")
);
CREATE TABLE IF NOT EXISTS "commands_fts_idx" (
	"segid"	,
	"term"	,
	"pgno"	,
	PRIMARY KEY("segid","term")
) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS "commands_fts_docsize" (
	"id"	INTEGER,
	"sz"	BLOB,
	PRIMARY KEY("id")
);
CREATE TABLE IF NOT EXISTS "commands_fts_config" (
	"k"	,
	"v"	,
	PRIMARY KEY("k")
) WITHOUT ROWID;
INSERT INTO "clu_metadata" ("key","value") VALUES ('db_version','2.0.0');
INSERT INTO "commands_fts_data" ("id","block") VALUES (1,'');
INSERT INTO "commands_fts_data" ("id","block") VALUES (10,X'00000000000000');
INSERT INTO "commands_fts_config" ("k","v") VALUES ('version',4);
CREATE TRIGGER commands_fts_insert AFTER INSERT ON commands
BEGIN
    INSERT INTO commands_fts (rowid, name, description, language, tags)

	VALUES (new.rowid, new.name, new.description, new.language,
			(
				SELECT GROUP_CONCAT(t.tag)
				FROM tags t
				INNER JOIN commands_tags ct on ct.tag_id = t.id
				INNER JOIN commands c on ct.command_id = c.id
				WHERE c.rowid = new.rowid
			)
	);
END;
CREATE TRIGGER commands_fts_delete AFTER DELETE ON commands
BEGIN
    INSERT INTO commands_fts
	(commands_fts, rowid, name, description, language, tags )
	VALUES
	('delete', old.rowid, old.name, old.description, old.language, old.tags);
END;
CREATE TRIGGER commands_fts_update AFTER UPDATE ON commands
BEGIN
    INSERT INTO commands_fts
	(commands_fts, rowid, name, description, language, tags)
	VALUES ('delete', old.rowid, old.name, old.description, old.language, old.tags);
    INSERT INTO commands_fts
	(rowid, name, description, language, tags)
	VALUES
	(new.rowid, new.name, new.description, new.language,
			(
				SELECT GROUP_CONCAT(t.tag)
				FROM tags t
				INNER JOIN commands_tags ct on ct.tag_id = t.id
				INNER JOIN commands c on ct.command_id = c.id
				WHERE c.rowid = new.rowid
			)
	);
END;
COMMIT;
