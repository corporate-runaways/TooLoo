BEGIN TRANSACTION;
CREATE TABLE IF NOT EXISTS "cheats" (
	"id"	INTEGER NOT NULL,
	"command_id"	INTEGER NOT NULL,
	"description"	TEXT NOT NULL,
	"template"	TEXT NOT NULL,
	FOREIGN KEY("command_id") REFERENCES "commands"("id"),
	PRIMARY KEY("id" AUTOINCREMENT)
);
CREATE VIRTUAL TABLE commands_fts USING fts5(
	id,
	name,
	description,
	language,
	content=commands,
	content_rowid=id,
	tokenize=porter
);
CREATE VIRTUAL TABLE tags_fts USING fts5(
	id,
	tag,
	content=tags,
	content_rowid=id,
	tokenize=porter
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
INSERT INTO "clu_metadata" ("key","value") VALUES ('db_version','2.0.0');
-- Commands FTS triggers
CREATE TRIGGER commands_fts_insert AFTER INSERT ON commands
BEGIN
    INSERT INTO commands_fts (rowid, name, description, language) VALUES (new.rowid, new.name, new.description, new.language);
END;
CREATE TRIGGER commands_fts_delete AFTER DELETE ON commands
BEGIN
    INSERT INTO commands_fts
	(commands_fts, rowid, name, description, language)
	VALUES
	('delete', old.rowid, old.name, old.description, old.language);
END;
CREATE TRIGGER commands_fts_update AFTER UPDATE ON commands
BEGIN
    INSERT INTO commands_fts
	(commands_fts, rowid, name, description, language)
	VALUES ('delete', old.rowid, old.name, old.description, old.language);
    INSERT INTO commands_fts
	(rowid, name, description, language)
	VALUES
	(new.rowid, new.name, new.description, new.language);
END;
COMMIT;
-- Tags FTS triggers
CREATE TRIGGER tags_fts_insert AFTER INSERT ON tags
BEGIN
    INSERT INTO tags_fts (rowid, tag) VALUES (new.rowid, new.tag);
END;
CREATE TRIGGER tags_fts_delete AFTER DELETE ON tags
BEGIN
    INSERT INTO tags_fts
	(tags_fts, rowid, tag)
	VALUES
	('delete', old.rowid, old.tag);
END;
CREATE TRIGGER tags_fts_update AFTER UPDATE ON tags
BEGIN
    INSERT INTO tags_fts
	(tags_fts, rowid, tag)
	VALUES ('delete', old.rowid, old.tag);
    INSERT INTO tags_fts
	(rowid, tag)
	VALUES
	(new.rowid, new.tag);
END;
COMMIT;
